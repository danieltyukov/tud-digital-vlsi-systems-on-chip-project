#!/usr/bin/env python3
import argparse
import gzip
import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple

BASELINE_LEGACY = {
    "setup_wns_ns": 33.845,
    "hold_wns_ns": 0.032,
    "accel_total_power_mw": 0.403,
    "chip_total_power_mw": 0.62627288,
    "accel_leakage_mw": 0.01268,
    "first_chunk_latency_us": 60.997560,
    "accel_chunk_energy_nj": 24.582,
    "synth_total_area": 194967.841,
    "final_total_area": 242796.265,
    "drv_max_tran_worst": -0.626,
    "annotation_coverage": "36524/36524 = 100%",
    "core_w_um": 596.4,
    "core_h_um": 596.4,
}

BASELINE_WINDOWED = {
    "setup_wns_ns": 33.845,
    "hold_wns_ns": 0.032,
    "accel_total_power_mw": 0.3347,
    "chip_total_power_mw": 0.55384318,
    "accel_leakage_mw": 0.01266,
    "first_chunk_latency_us": 60.997560,
    "accel_chunk_energy_nj": 20.415883,
    "synth_total_area": 194967.841,
    "final_total_area": 242796.265,
    "drv_max_tran_worst": -0.626,
    "annotation_coverage": "36524/36524 = 100%",
    "core_w_um": 596.4,
    "core_h_um": 596.4,
}


def read_text(path: Path) -> Optional[str]:
    if not path.exists():
        return None
    try:
        return path.read_text(errors="ignore")
    except Exception:
        return None


def read_gz_text(path: Path) -> Optional[str]:
    if not path.exists():
        return None
    try:
        with gzip.open(path, "rt", errors="ignore") as f:
            return f.read()
    except Exception:
        return None


def find_step11_innovus_log(root: Path) -> Optional[Path]:
    pnr = root / "pnr"
    if not pnr.exists():
        return None
    step11_marker = 'Sourcing file "./scripts/11.finalPowerReports.tcl"'
    logs = sorted(
        [p for p in pnr.glob("innovus.log*") if re.fullmatch(r"innovus\.log\d*", p.name)],
        key=lambda p: p.stat().st_mtime,
        reverse=True,
    )
    for p in logs:
        txt = read_text(p)
        if txt and step11_marker in txt:
            return p
    fallback = pnr / "innovus.log"
    if fallback.exists():
        return fallback
    return logs[0] if logs else None


def first_match(text: Optional[str], pattern: str, group: int = 1) -> Optional[str]:
    if not text:
        return None
    m = re.search(pattern, text, re.MULTILINE)
    return m.group(group).strip() if m else None


def fmt(v: Optional[str]) -> str:
    return v if v else "N/A"


def parse_clock_periods(report_text: Optional[str]) -> Dict[str, str]:
    out = {}
    if not report_text:
        return out
    for clk in ["clk", "flash_clk"]:
        m = re.search(
            rf"\|\s*{re.escape(clk)}\s*\|[^|]*\|[^|]*\|\s*([-\d.]+)\s*\|",
            report_text,
        )
        if m:
            out[clk] = m.group(1)
    return out


def parse_synth_qor(qor_text: Optional[str]) -> Dict[str, str]:
    data = {}
    if not qor_text:
        return data

    clk_period = first_match(qor_text, r"^\s*clk\s+([-\d.]+)\s*$")
    flash_period = first_match(qor_text, r"^\s*flash_clk\s+([-\d.]+)\s*$")
    if clk_period:
        data["clk_period_ps"] = clk_period
    if flash_period:
        data["flash_period_ps"] = flash_period

    m_clk = re.search(r"^\s*clk\s+([-\d.]+)\s+([-\d.]+)\s+(\d+)\s*$", qor_text, re.MULTILINE)
    m_flash = re.search(r"^\s*flash_clk\s+([-\d.]+)\s+([-\d.]+)\s+(\d+)\s*$", qor_text, re.MULTILINE)
    if m_clk:
        data["clk_slack_ps"] = m_clk.group(1)
        data["clk_tns"] = m_clk.group(2)
        data["clk_viol_paths"] = m_clk.group(3)
    if m_flash:
        data["flash_slack_ps"] = m_flash.group(1)
        data["flash_tns"] = m_flash.group(2)
        data["flash_viol_paths"] = m_flash.group(3)

    total_tns = first_match(qor_text, r"^\s*Total\s+([-\d.]+)\s+\d+\s*$")
    if total_tns:
        data["total_tns"] = total_tns
    return data


def parse_transcript_metrics(text: Optional[str]) -> Dict[str, str]:
    d = {}
    if not text:
        return d
    d["complete_cycles"] = first_match(text, r"Complete latency in Clock Cycles:\s*([-\d]+)")
    d["accel_cycles"] = first_match(text, r"Accelerator runtime in Clock Cycles:\s*([^\n]+)")
    d["complete_ms"] = first_match(text, r"Complete latency in Milliseconds:\s*([-\d.]+)")
    d["accel_ms"] = first_match(text, r"Accelerator runtime in Milliseconds:\s*([^\n]+)")
    d["first_chunk_us"] = first_match(text, r"Latency of first chunk is \(MICROseconds\):\s*([-\d.]+)")
    d["first_chunk_start_ms"] = first_match(
        text, r"Acceleration of first chunk started at \(Milliseconds\):\s*([-\d.]+)"
    )
    return d


def parse_timing_summary(text: Optional[str]) -> Dict[str, str]:
    d = {}
    if not text:
        return d
    d["mode"] = "Hold" if "Hold mode" in text else "Setup"
    m_wns = re.search(r"\|\s*WNS \(ns\):\|\s*([-\d.]+)\s*\|\s*([-\d.]+)\s*\|\s*([-\d.]+)\s*\|", text)
    m_tns = re.search(r"\|\s*TNS \(ns\):\|\s*([-\d.]+)\s*\|\s*([-\d.]+)\s*\|\s*([-\d.]+)\s*\|", text)
    m_vio = re.search(r"\|\s*Violating Paths:\|\s*([-\d.]+)\s*\|\s*([-\d.]+)\s*\|\s*([-\d.]+)\s*\|", text)
    if m_wns:
        d["wns_all"] = m_wns.group(1)
    if m_tns:
        d["tns_all"] = m_tns.group(1)
    if m_vio:
        d["viol_all"] = m_vio.group(1)
    m_tran = re.search(
        r"\|\s*max_tran\s*\|\s*([^|]+?)\s*\|\s*([-\d.]+)\s*\|\s*([^|]+?)\s*\|",
        text,
    )
    if m_tran:
        d["max_tran_real"] = " ".join(m_tran.group(1).split())
        d["max_tran_worst"] = m_tran.group(2)
    for drv_key in ["max_cap", "max_fanout", "max_length"]:
        m_drv = re.search(
            rf"\|\s*{drv_key}\s*\|\s*([^|]+?)\s*\|\s*([-\d.]+)\s*\|\s*([^|]+?)\s*\|",
            text,
        )
        if m_drv:
            d[f"{drv_key}_real"] = " ".join(m_drv.group(1).split())
            d[f"{drv_key}_worst"] = m_drv.group(2)
    return d


def parse_power_report(text: Optional[str]) -> Dict[str, str]:
    d = {}
    if not text:
        return d
    d["coverage"] = first_match(text, r"Design annotation coverage:\s*([^\n]+)")
    d["internal"] = first_match(text, r"Total Internal Power:\s*([-\deE+.]+)")
    d["switching"] = first_match(text, r"Total Switching Power:\s*([-\deE+.]+)")
    d["leakage"] = first_match(text, r"Total Leakage Power:\s*([-\deE+.]+)")
    d["total"] = first_match(text, r"Total Power:\s*([-\deE+.]+)")
    d["clock_period_usec"] = first_match(text, r"Clock Period:\s*([-\d.]+)\s*usec")
    d["clock_toggle_mhz"] = first_match(text, r"Clock Toggle Rate:\s*([-\d.]+)\s*Mhz")
    return d


def parse_final_power_hierarchy(text: Optional[str]) -> Dict[str, str]:
    d = {}
    if not text:
        return d
    accel = re.search(
        r"^\s*accel\s+([-\deE+.]+)\s+([-\deE+.]+)\s+([-\deE+.]+)\s+([-\deE+.]+)\s+([-\deE+.]+)",
        text,
        re.MULTILINE,
    )
    soc = re.search(
        r"^\s*soc\s+([-\deE+.]+)\s+([-\deE+.]+)\s+([-\deE+.]+)\s+([-\deE+.]+)\s+([-\deE+.]+)",
        text,
        re.MULTILINE,
    )
    clk = re.search(
        r"^\s*clk\s+([-\deE+.]+)\s+([-\deE+.]+)\s+([-\deE+.]+)\s+([-\deE+.]+)\s+([-\deE+.]+)",
        text,
        re.MULTILINE,
    )
    if accel:
        d["accel_internal"] = accel.group(1)
        d["accel_switching"] = accel.group(2)
        d["accel_leakage"] = accel.group(3)
        d["accel_total"] = accel.group(4)
    if soc:
        d["soc_total"] = soc.group(4)
    if clk:
        d["clk_total"] = clk.group(4)
    return d


def parse_area_values(synth_area_text: Optional[str], final_area_text: Optional[str]) -> Dict[str, str]:
    d = {}
    if synth_area_text:
        m = re.search(r"^\s*et4351\s+(\d+)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s*$", synth_area_text, re.MULTILINE)
        if m:
            d["synth_cell_count"] = m.group(1)
            d["synth_cell_area"] = m.group(2)
            d["synth_net_area"] = m.group(3)
            d["synth_total_area"] = m.group(4)
    if final_area_text:
        m = re.search(r"^\s*et4351\s+\d+\s+([-\d.]+)\s*$", final_area_text, re.MULTILINE)
        if m:
            d["final_total_area"] = m.group(1)
    return d


def parse_signoff_status(root: Path) -> Dict[str, str]:
    d = {}
    drc = read_text(root / "pnr/verifyReports/verify_drc.rpt")
    conn = read_text(root / "pnr/verifyReports/verifyConnectivity.rpt")
    ant = read_text(root / "pnr/verifyReports/verifyProcessAntenna.rpt")
    place = read_text(root / "pnr/verifyReports/checkPlace.rpt")
    cts = read_text(root / "pnr/verifyReports/cts_check_timing.rpt")

    d["drc"] = "Clean" if drc and "No DRC violations were found" in drc else "Check report"
    d["connectivity"] = "Clean" if conn and "Found no problems or warnings." in conn else "Check report"
    d["antenna"] = "Clean" if ant and "No Violations Found" in ant else "Check report"
    d["place"] = "Clean" if place and "No violations found" in place else "Check report"
    d["cts_warning_ideal_clock"] = first_match(cts, r"ideal_clock_waveform\s+\|[^\n|]*\|\s*([0-9]+)\s*\|")
    d["cts_warning_no_input_delay"] = first_match(cts, r"no_input_delay\s+\|[^\n|]*\|\s*([0-9]+)\s*\|")
    d["cts_warning_uncons_endpoint"] = first_match(cts, r"uncons_endpoint\s+\|[^\n|]*\|\s*([0-9]+)\s*\|")

    # Extract fixed core dimensions from floorplan command if available.
    innovus_cmd = read_text(root / "pnr/innovus.cmd")
    m_floor = None
    if innovus_cmd:
        m_floor = re.search(r"floorPlan\s+-site\s+\S+\s+-s\s+([-\d.]+)\s+([-\d.]+)\s+", innovus_cmd)
    if not m_floor:
        innovus_log = read_text(root / "pnr/innovus.log")
        if innovus_log:
            m_floor = re.search(r"<CMD>\s*floorPlan\s+-site\s+\S+\s+-s\s+([-\d.]+)\s+([-\d.]+)\s+", innovus_log)
    if m_floor:
        d["core_w_um"] = m_floor.group(1)
        d["core_h_um"] = m_floor.group(2)

    return d


def parse_annotation_from_innovus(log_text: Optional[str]) -> Dict[str, str]:
    d = {}
    if not log_text:
        return d
    d["coverage_file"] = first_match(
        log_text,
        r"Annotation coverage for this file[\s\S]*?:\s*([0-9]+/[0-9]+\s*=\s*[0-9.]+%)",
    )
    d["coverage_total"] = first_match(
        log_text, r"Total annotation coverage for all files of type VCD:\s*([0-9/=\s.%]+)"
    )
    d["zero_toggle"] = first_match(
        log_text, r"Percent of VCD annotated nets with zero toggles:\s*([0-9/=\s.%]+)"
    )
    d["missing_nets"] = first_match(log_text, r"\n\s*([0-9]+)\s+nets were found in the VCD file")
    return d


def parse_vcd_window_from_cmd(cmd_text: Optional[str]) -> Dict[str, str]:
    d = {}
    if not cmd_text:
        return d
    runs = re.findall(r"^\s*run\s+([-\d.]+)\s*(ms|us|ns)\s*$", cmd_text, re.MULTILINE)
    # In provided scripts, first run is start offset, second run is capture duration.
    if len(runs) >= 2:
        d["start_val"] = runs[0][0]
        d["start_unit"] = runs[0][1]
        d["dur_val"] = runs[1][0]
        d["dur_unit"] = runs[1][1]
    d["has_vcd_on_off"] = "yes" if ("vcd on" in cmd_text and "vcd off" in cmd_text) else "no"
    return d


def to_ms(v: Optional[str], unit: Optional[str]) -> Optional[float]:
    fv = parse_float(v)
    if fv is None or unit is None:
        return None
    u = unit.lower()
    if u == "ms":
        return fv
    if u == "us":
        return fv / 1000.0
    if u == "ns":
        return fv / 1_000_000.0
    return None


def to_us(v: Optional[str], unit: Optional[str]) -> Optional[float]:
    fv = parse_float(v)
    if fv is None or unit is None:
        return None
    u = unit.lower()
    if u == "us":
        return fv
    if u == "ms":
        return fv * 1000.0
    if u == "ns":
        return fv / 1000.0
    return None


def find_geometry_report(root: Path) -> Optional[Path]:
    vr = root / "pnr/verifyReports"
    if not vr.exists():
        return None
    for p in sorted(vr.glob("*")):
        if re.search(r"geo|geometry", p.name, re.IGNORECASE):
            return p
    return None


def has_finaldesign_package(root: Path) -> Tuple[bool, str]:
    # Accept either finaldesign/ (project description) or finaldesign_hp + finaldesign_ee (template/rubric).
    fd = root / "finaldesign"
    if fd.exists():
        needed = ["accel_audio.hex", "et4351.phys.sdf", "et4351.phys.v"]
        missing = [n for n in needed if not (fd / n).exists()]
        if missing:
            return False, f"finaldesign/ missing: {', '.join(missing)}"
        return True, "finaldesign/ contains accel_audio.hex, et4351.phys.sdf, et4351.phys.v"

    hp = root / "finaldesign_hp"
    ee = root / "finaldesign_ee"
    if hp.exists() and ee.exists():
        needed = ["accel_audio.hex", "et4351.phys.sdf", "et4351.phys.v"]
        missing = []
        for d in [hp, ee]:
            for n in needed:
                if not (d / n).exists():
                    missing.append(f"{d.name}/{n}")
        if missing:
            return False, f"missing: {', '.join(missing)}"
        return True, "finaldesign_hp/ and finaldesign_ee/ both contain required 3 files"

    return False, "No finaldesign/ or finaldesign_hp+finaldesign_ee packaging found"


def check_firmware_handshake(root: Path) -> Tuple[str, str]:
    c_path = root / "firmware/accel_audio.c"
    txt = read_text(c_path)
    if not txt:
        return "N/A", "firmware/accel_audio.c not found"
    idx_en = txt.find("MASK_CSR_ENABLE")
    idx_wait = txt.find("while (!(REG_CONFIG_AND_STATUS & MASK_CSR_DONE))")
    idx_dis = txt.find("~MASK_CSR_ENABLE")
    if idx_en >= 0 and idx_wait >= 0 and idx_dis >= 0 and idx_en < idx_wait < idx_dis:
        return "PASS", "Found enable -> wait(done) -> disable sequence in accelerated_fft flow"
    return "WARN", "Could not confirm ordered enable/wait/disable handshake pattern"


def build_project_description_checks(
    root: Path,
    clocks: Dict[str, str],
    timing_map: Dict[str, Dict[str, str]],
    signoff: Dict[str, str],
    sim_behav: Dict[str, str],
    ann_log: Dict[str, str],
    accel_energy: Optional[float],
) -> List[Tuple[str, str, str]]:
    rows: List[Tuple[str, str, str]] = []

    # Core area fixed
    core_w = parse_float(signoff.get("core_w_um"))
    core_h = parse_float(signoff.get("core_h_um"))
    core_ok = (
        core_w is not None
        and core_h is not None
        and abs(core_w - BASELINE_WINDOWED["core_w_um"]) <= 1e-6
        and abs(core_h - BASELINE_WINDOWED["core_h_um"]) <= 1e-6
    )
    rows.append(
        (
            "Fixed core area 596.4um x 596.4um",
            yn(core_ok),
            f"floorPlan -s {fmt(signoff.get('core_w_um'))} {fmt(signoff.get('core_h_um'))}",
        )
    )

    # Timing clean
    s_v = parse_float(timing_map.get("final_setup", {}).get("viol_all"))
    h_v = parse_float(timing_map.get("final_hold", {}).get("viol_all"))
    s_tns = parse_float(timing_map.get("final_setup", {}).get("tns_all"))
    h_tns = parse_float(timing_map.get("final_hold", {}).get("tns_all"))
    s_wns = parse_float(timing_map.get("final_setup", {}).get("wns_all"))
    h_wns = parse_float(timing_map.get("final_hold", {}).get("wns_all"))
    setup_clean = s_v == 0 and s_tns == 0 and s_wns is not None and s_wns >= 0
    hold_clean = h_v == 0 and h_tns == 0 and h_wns is not None and h_wns >= 0
    rows.append(("Setup timing clean", yn(setup_clean), f"WNS={fmt(timing_map.get('final_setup', {}).get('wns_all'))}, TNS={fmt(timing_map.get('final_setup', {}).get('tns_all'))}, Vio={fmt(timing_map.get('final_setup', {}).get('viol_all'))}"))
    rows.append(("Hold timing clean", yn(hold_clean), f"WNS={fmt(timing_map.get('final_hold', {}).get('wns_all'))}, TNS={fmt(timing_map.get('final_hold', {}).get('tns_all'))}, Vio={fmt(timing_map.get('final_hold', {}).get('viol_all'))}"))

    # DRV clean except max_tran
    drv = timing_map.get("final_setup", {})
    max_cap_ok = is_clean_zero_violation(drv.get("max_cap_real"))
    max_fanout_ok = is_clean_zero_violation(drv.get("max_fanout_real"))
    max_length_ok = is_clean_zero_violation(drv.get("max_length_real"))
    rows.append(("DRV clean (max_cap)", yn(max_cap_ok), f"real={fmt(drv.get('max_cap_real'))}"))
    rows.append(("DRV clean (max_fanout)", yn(max_fanout_ok), f"real={fmt(drv.get('max_fanout_real'))}"))
    rows.append(("DRV clean (max_length)", yn(max_length_ok), f"real={fmt(drv.get('max_length_real'))}"))
    rows.append(("max_tran violations acceptable note", "WARN", f"real={fmt(drv.get('max_tran_real'))}, worst={fmt(drv.get('max_tran_worst'))}"))

    # Connectivity, geometry, antenna clean
    rows.append(("Connectivity clean", "PASS" if signoff.get("connectivity") == "Clean" else "FAIL", "verifyConnectivity"))
    geo_report = find_geometry_report(root)
    if geo_report:
        geo_text = read_text(geo_report)
        geo_clean = bool(
            geo_text
            and (
                "No violations" in geo_text
                or "No DRC violations were found" in geo_text
                or "Found no problems or warnings." in geo_text
            )
        )
        rows.append(("Geometry report clean", "PASS" if geo_clean else "FAIL", str(geo_report.relative_to(root))))
    else:
        drc_proxy = "PASS" if signoff.get("drc") == "Clean" else "FAIL"
        rows.append(("Geometry report clean", "WARN", f"Explicit geometry report not found; DRC proxy={drc_proxy}"))
    rows.append(("Antenna clean", "PASS" if signoff.get("antenna") == "Clean" else "FAIL", "verifyProcessAntenna"))

    # FFT correctness on variable chunk count
    has_outputs = (root / "sim_behav/outputs.txt").exists()
    has_expected = (root / "firmware/expected_output.txt").exists()
    has_verify = (root / "sw/verify.py").exists()
    if has_outputs and has_expected and has_verify:
        rows.append(("FFT correctness (variable chunks)", "N/A", "Artifacts present (outputs + expected + verify.py); full correctness requires execution/private tests"))
    else:
        rows.append(("FFT correctness (variable chunks)", "WARN", "Missing one or more of outputs.txt / expected_output.txt / verify.py"))

    # HP / EE targets + min EE clock
    lat_us = parse_float(sim_behav.get("first_chunk_us"))
    hp_ok = lat_us is not None and lat_us < 61.0
    rows.append(("HP target latency < 61.00 us", yn(hp_ok), f"first chunk latency={fmt(sim_behav.get('first_chunk_us'))} us"))
    ee_ok = accel_energy is not None and accel_energy < 24.6
    rows.append(("EE target energy < 24.6 nJ", yn(ee_ok), f"accel chunk energy={fmt(None if accel_energy is None else f'{accel_energy:.6f}')} nJ"))
    clk_ns = parse_float(clocks.get("clk"))
    clk_mhz = (1000.0 / clk_ns) if clk_ns and clk_ns > 0 else None
    ee_clk_ok = clk_mhz is not None and clk_mhz >= 10.0
    rows.append(("EE minimum clock >= 10 MHz", yn(ee_clk_ok), f"clk={fmt(None if clk_mhz is None else f'{clk_mhz:.4f}')} MHz"))

    # Software start/done/disable requirement
    fw_status, fw_ev = check_firmware_handshake(root)
    rows.append(("Software accelerator handshake", fw_status, fw_ev))

    # Power estimation + annotation coverage
    final_pwr = get_final_power_report_path(root)
    pwr_rpt_ok = final_pwr is not None
    rows.append(
        (
            "Post-layout power estimation report",
            "PASS" if pwr_rpt_ok else "FAIL",
            str(final_pwr.relative_to(root)) if final_pwr else "Missing final power report",
        )
    )
    cov = ann_log.get("coverage_total")
    cov_ok = cov is not None and "100%" in cov
    rows.append(("Activity annotation coverage 100%", yn(cov_ok), fmt(cov)))

    # VCD start/duration window checks from all scripts used for power flow.
    vcd_targets: List[Tuple[str, Path]] = [
        ("struct", root / "sim_struct/scripts/run_vcd.cmd"),
        ("phys_setup", root / "sim_phys/scripts/run_vcd_setup.cmd"),
        ("phys_hold", root / "sim_phys/scripts/run_vcd_hold.cmd"),
    ]
    vcd_details = []
    vcd_parsed = []
    for label, path in vcd_targets:
        parsed = parse_vcd_window_from_cmd(read_text(path))
        vcd_parsed.append((label, parsed))
        vcd_details.append(
            f"{label}: start={fmt(parsed.get('start_val'))}{fmt(parsed.get('start_unit'))}, "
            f"dur={fmt(parsed.get('dur_val'))}{fmt(parsed.get('dur_unit'))}, on/off={fmt(parsed.get('has_vcd_on_off'))}"
        )
    has_window = all(
        all(p.get(k) for k in ["start_val", "start_unit", "dur_val", "dur_unit"]) and p.get("has_vcd_on_off") == "yes"
        for _, p in vcd_parsed
    )
    rows.append(("VCD start+duration configured", "PASS" if has_window else "FAIL", " ; ".join(vcd_details)))

    # VCD window consistency with behavioral run numbers (for all VCD scripts).
    beh_start_ms = parse_float(sim_behav.get("first_chunk_start_ms"))
    beh_dur_us = parse_float(sim_behav.get("first_chunk_us"))
    per_vcd_match = []
    for label, p in vcd_parsed:
        vcd_start_ms = to_ms(p.get("start_val"), p.get("start_unit"))
        vcd_dur_us = to_us(p.get("dur_val"), p.get("dur_unit"))
        start_match = beh_start_ms is not None and vcd_start_ms is not None and abs(beh_start_ms - vcd_start_ms) <= 1e-3
        dur_match = beh_dur_us is not None and vcd_dur_us is not None and abs(beh_dur_us - vcd_dur_us) <= 1e-3
        per_vcd_match.append(
            f"{label}: beh_start={fmt(sim_behav.get('first_chunk_start_ms'))}ms vs cmd_start={fmt(None if vcd_start_ms is None else f'{vcd_start_ms:.6f}')}ms, "
            f"beh_dur={fmt(sim_behav.get('first_chunk_us'))}us vs cmd_dur={fmt(None if vcd_dur_us is None else f'{vcd_dur_us:.6f}')}us"
        )
    win_match = all("N/A" not in s and "vs cmd_start=" in s for s in per_vcd_match) and all(
        (
            beh_start_ms is not None
            and to_ms(p.get("start_val"), p.get("start_unit")) is not None
            and abs(beh_start_ms - to_ms(p.get("start_val"), p.get("start_unit"))) <= 1e-3
            and beh_dur_us is not None
            and to_us(p.get("dur_val"), p.get("dur_unit")) is not None
            and abs(beh_dur_us - to_us(p.get("dur_val"), p.get("dur_unit"))) <= 1e-3
        )
        for _, p in vcd_parsed
    )
    rows.append(
        (
            "VCD window matches behavioral start/runtime",
            "PASS" if win_match else "WARN",
            " ; ".join(per_vcd_match),
        )
    )

    # Finaldesign packaging requirement
    fd_ok, fd_ev = has_finaldesign_package(root)
    rows.append(("Submission finaldesign package files", "PASS" if fd_ok else "WARN", fd_ev))

    # Testbench compatibility requirement (cannot be fully auto-checked)
    tb_exists = (root / "src/testbench/tb_et4351.sv").exists()
    rows.append(("Testbench compatibility (tb_et4351.sv unmodified)", "N/A", "Cannot auto-verify unchanged baseline here; file present" if tb_exists else "tb_et4351.sv missing"))

    return rows


def find_power_reports(root: Path) -> List[Path]:
    ordered = [
        root / "pnr/powerReports/prePlace_VCDImport.rpt",
        root / "pnr/powerReports/preCTS.rpt",
        root / "pnr/powerReports/postCTSHold.rpt",
        root / "pnr/powerReports/route.rpt",
        root / "pnr/powerReports/postRoute.rpt",
        root / "pnr/powerReports/postRouteHold.rpt",
        root / "pnr/finalReports/report_power_postRouteVCD.rpt",
        root / "pnr/finalReports/report_power.rpt",
    ]
    return [p for p in ordered if p.exists()]


def get_final_power_report_path(root: Path) -> Optional[Path]:
    candidates = [
        root / "pnr/finalReports/report_power_postRouteVCD.rpt",
        root / "pnr/finalReports/report_power.rpt",
    ]
    for p in candidates:
        if p.exists():
            return p
    return None


def parse_float(v: Optional[str]) -> Optional[float]:
    if not v:
        return None
    try:
        return float(v)
    except Exception:
        return None


def compare_vs_baseline_rows(
    baseline: Dict[str, object],
    setup_wns: Optional[float],
    hold_wns: Optional[float],
    accel_total_power: Optional[float],
    chip_total_power: Optional[float],
    accel_leakage: Optional[float],
    latency_us: Optional[float],
    accel_energy_nj: Optional[float],
    synth_area: Optional[float],
    final_area: Optional[float],
    drv_max_tran_worst: Optional[float],
    coverage: Optional[str],
) -> List[Tuple[str, str, str, str, str]]:
    rows: List[Tuple[str, str, str, str, str]] = []

    def num_row(metric: str, current: Optional[float], baseline: float, unit: str, larger_is_better: bool) -> Tuple[str, str, str, str, str]:
        if current is None:
            return (metric, "N/A", f"{baseline:.6g} {unit}", "N/A", "N/A")
        delta = current - baseline
        tolerance = 1e-4
        if abs(delta) <= tolerance:
            status = "same"
        elif (delta > 0 and larger_is_better) or (delta < 0 and not larger_is_better):
            status = "better"
        else:
            status = "worse"
        return (metric, f"{current:.6g} {unit}", f"{baseline:.6g} {unit}", f"{delta:+.6g} {unit}", status)

    rows.append(num_row("Setup WNS", setup_wns, baseline["setup_wns_ns"], "ns", larger_is_better=True))
    rows.append(num_row("Hold WNS", hold_wns, baseline["hold_wns_ns"], "ns", larger_is_better=True))
    rows.append(
        num_row(
            "Accelerator total power",
            accel_total_power,
            baseline["accel_total_power_mw"],
            "mW",
            larger_is_better=False,
        )
    )
    rows.append(
        num_row(
            "Chip total power",
            chip_total_power,
            baseline["chip_total_power_mw"],
            "mW",
            larger_is_better=False,
        )
    )
    rows.append(
        num_row(
            "Accelerator leakage",
            accel_leakage,
            baseline["accel_leakage_mw"],
            "mW",
            larger_is_better=False,
        )
    )
    rows.append(
        num_row(
            "First-chunk latency",
            latency_us,
            baseline["first_chunk_latency_us"],
            "us",
            larger_is_better=False,
        )
    )
    rows.append(
        num_row(
            "Accelerator chunk energy",
            accel_energy_nj,
            baseline["accel_chunk_energy_nj"],
            "nJ",
            larger_is_better=False,
        )
    )
    rows.append(
        num_row(
            "Synthesis total area",
            synth_area,
            baseline["synth_total_area"],
            "um^2",
            larger_is_better=False,
        )
    )
    rows.append(
        num_row(
            "Final placed total area",
            final_area,
            baseline["final_total_area"],
            "um^2",
            larger_is_better=False,
        )
    )
    rows.append(
        num_row(
            "DRV max_tran worst",
            drv_max_tran_worst,
            baseline["drv_max_tran_worst"],
            "ns",
            larger_is_better=True,
        )
    )

    cov_current = coverage if coverage else "N/A"
    cov_base = baseline["annotation_coverage"]
    cov_status = "same" if cov_current == cov_base else "different"
    rows.append(("Annotation coverage", cov_current, cov_base, "N/A", cov_status))

    return rows


def is_clean_zero_violation(v: Optional[str]) -> Optional[bool]:
    if v is None:
        return None
    return v.strip() in {"0 (0)", "0"}


def yn(v: Optional[bool]) -> str:
    if v is None:
        return "N/A"
    return "PASS" if v else "FAIL"


def build_markdown(root: Path) -> str:
    run_name = root.name
    run_path = str(root)

    clocks_text = read_text(root / "pnr/initialReports/report_clocks.rpt")
    qor_text = read_text(root / "synth/reports/struct/et4351_qor.rpt")
    final_power_path = get_final_power_report_path(root)
    final_power_name = final_power_path.name if final_power_path else ""
    final_power_rel = str(final_power_path.relative_to(root)) if final_power_path else "N/A"
    final_power_text = read_text(final_power_path) if final_power_path else None
    innovus_log_path = find_step11_innovus_log(root)
    innovus_log = read_text(innovus_log_path) if innovus_log_path else None
    innovus_log_rel = str(innovus_log_path.relative_to(root)) if innovus_log_path else "N/A"
    synth_area_text = read_text(root / "synth/reports/struct/et4351_area.rpt")
    final_area_text = read_text(root / "pnr/finalReports/report_area.rpt")

    clocks = parse_clock_periods(clocks_text)
    qor = parse_synth_qor(qor_text)
    power_hier = parse_final_power_hierarchy(final_power_text)
    legacy_power_text = read_text(root / "pnr/finalReports/report_power.rpt")
    windowed_power_text = read_text(root / "pnr/finalReports/report_power_postRouteVCD.rpt")
    legacy_power_hier = parse_final_power_hierarchy(legacy_power_text)
    windowed_power_hier = parse_final_power_hierarchy(windowed_power_text)
    ann_log = parse_annotation_from_innovus(innovus_log)
    areas = parse_area_values(synth_area_text, final_area_text)
    signoff = parse_signoff_status(root)

    sim_behav = parse_transcript_metrics(read_text(root / "sim_behav/transcript"))
    sim_struct = parse_transcript_metrics(read_text(root / "sim_struct/transcript"))
    sim_phys = parse_transcript_metrics(read_text(root / "sim_phys/transcript"))

    timing_stage_files: List[Tuple[str, Path]] = [
        ("preCTS", root / "pnr/timingReports/preCTS/et4351_preCTS.summary.gz"),
        ("preCTS_hold", root / "pnr/timingReports/preCTS_hold/et4351_preCTS_hold.summary.gz"),
        ("postCTS", root / "pnr/timingReports/et4351_postCTS.summary.gz"),
        ("postCTS_hold", root / "pnr/timingReports/postCTSHold_hold/et4351_postCTS_hold.summary.gz"),
        ("route", root / "pnr/timingReports/route/et4351_postRoute.summary.gz"),
        ("route_hold", root / "pnr/timingReports/route_hold/et4351_postRoute_hold.summary.gz"),
        ("postRoute_hold_intermediate", root / "pnr/timingReports/postRoute_hold/et4351_postRoute_hold.summary.gz"),
        ("final_setup", root / "pnr/finalReports/report_timing/et4351_postRoute.summary.gz"),
        ("final_hold", root / "pnr/finalReports/report_timing_hold/et4351_postRoute_hold.summary.gz"),
    ]
    timing_rows = []
    timing_map = {}
    for label, p in timing_stage_files:
        t = parse_timing_summary(read_gz_text(p))
        if t:
            timing_map[label] = t
            max_tran = "n/a"
            if t.get("max_tran_real"):
                max_tran = f"{t['max_tran_real']}, worst {t.get('max_tran_worst', 'N/A')}"
            timing_rows.append(
                f"| `{p.relative_to(root)}` | {fmt(t.get('mode'))} | {fmt(t.get('wns_all'))} | {fmt(t.get('tns_all'))} | {fmt(t.get('viol_all'))} | {max_tran} |"
            )

    power_rows = []
    power_reports = find_power_reports(root)
    power_map: Dict[str, Dict[str, str]] = {}
    for p in power_reports:
        pr = parse_power_report(read_text(p))
        power_map[p.name] = pr
        power_rows.append(
            f"| `{p.relative_to(root)}` | {fmt(pr.get('internal'))} | {fmt(pr.get('switching'))} | {fmt(pr.get('leakage'))} | {fmt(pr.get('total'))} | {fmt(pr.get('coverage'))} |"
        )

    chunk_latency_us = parse_float(sim_behav.get("first_chunk_us"))
    accel_total_mw = parse_float(power_hier.get("accel_total"))
    chip_total_mw = parse_float(power_map.get(final_power_name, {}).get("total")) if final_power_name else None
    accel_energy = None
    chip_energy = None
    if chunk_latency_us is not None and accel_total_mw is not None:
        accel_energy = accel_total_mw * chunk_latency_us
    if chunk_latency_us is not None and chip_total_mw is not None:
        chip_energy = chip_total_mw * chunk_latency_us

    legacy_accel_total_mw = parse_float(legacy_power_hier.get("accel_total"))
    legacy_chip_total_mw = parse_float(power_map.get("report_power.rpt", {}).get("total"))
    legacy_accel_energy = legacy_accel_total_mw * chunk_latency_us if (legacy_accel_total_mw is not None and chunk_latency_us is not None) else None

    windowed_accel_total_mw = parse_float(windowed_power_hier.get("accel_total"))
    windowed_chip_total_mw = parse_float(power_map.get("report_power_postRouteVCD.rpt", {}).get("total"))
    windowed_accel_energy = windowed_accel_total_mw * chunk_latency_us if (windowed_accel_total_mw is not None and chunk_latency_us is not None) else None

    common_compare_args = dict(
        setup_wns=parse_float(timing_map.get("final_setup", {}).get("wns_all")),
        hold_wns=parse_float(timing_map.get("final_hold", {}).get("wns_all")),
        latency_us=chunk_latency_us,
        synth_area=parse_float(areas.get("synth_total_area")),
        final_area=parse_float(areas.get("final_total_area")),
        drv_max_tran_worst=parse_float(timing_map.get("final_setup", {}).get("max_tran_worst")),
        coverage=ann_log.get("coverage_total"),
    )
    comparison_rows_legacy = compare_vs_baseline_rows(
        baseline=BASELINE_LEGACY,
        accel_total_power=legacy_accel_total_mw,
        chip_total_power=legacy_chip_total_mw,
        accel_leakage=parse_float(legacy_power_hier.get("accel_leakage")),
        accel_energy_nj=legacy_accel_energy,
        **common_compare_args,
    )
    comparison_rows_windowed = compare_vs_baseline_rows(
        baseline=BASELINE_WINDOWED,
        accel_total_power=windowed_accel_total_mw,
        chip_total_power=windowed_chip_total_mw,
        accel_leakage=parse_float(windowed_power_hier.get("accel_leakage")),
        accel_energy_nj=windowed_accel_energy,
        **common_compare_args,
    )
    project_desc_checks = build_project_description_checks(
        root=root,
        clocks=clocks,
        timing_map=timing_map,
        signoff=signoff,
        sim_behav=sim_behav,
        ann_log=ann_log,
        accel_energy=accel_energy,
    )
    comparison_rows_legacy_md = [
        f"| {metric} | {current_v} | {baseline_v} | {delta_v} | {status_v} |"
        for metric, current_v, baseline_v, delta_v, status_v in comparison_rows_legacy
    ]
    comparison_rows_windowed_md = [
        f"| {metric} | {current_v} | {baseline_v} | {delta_v} | {status_v} |"
        for metric, current_v, baseline_v, delta_v, status_v in comparison_rows_windowed
    ]
    legacy_source = "`pnr/finalReports/report_power.rpt`" if (root / "pnr/finalReports/report_power.rpt").exists() else "missing (`pnr/finalReports/report_power.rpt`)"
    windowed_source = (
        "`pnr/finalReports/report_power_postRouteVCD.rpt`"
        if (root / "pnr/finalReports/report_power_postRouteVCD.rpt").exists()
        else "missing (`pnr/finalReports/report_power_postRouteVCD.rpt`)"
    )
    project_desc_rows_md = [
        f"| {req} | {result} | {evidence} |"
        for req, result, evidence in project_desc_checks
    ]

    return f"""# Key Metrics (Timing + Power)

Run folder: **{run_name}**  
Run path: `{run_path}`

This summary is generated automatically from the baseline report files.

## 1) Clock and Latency Metrics

### Clocks
- `clk` period: **{fmt(clocks.get('clk'))} ns**
- `flash_clk` period: **{fmt(clocks.get('flash_clk'))} ns**

Source: `pnr/initialReports/report_clocks.rpt`

### Simulation Latency
- Behavioral simulation (`sim_behav/transcript`):
  - Complete latency: **{fmt(sim_behav.get('complete_cycles'))} cycles**
  - Accelerator runtime: **{fmt(sim_behav.get('accel_cycles'))}**
  - Complete latency: **{fmt(sim_behav.get('complete_ms'))} ms**
  - Accelerator runtime: **{fmt(sim_behav.get('accel_ms'))}**
  - First chunk latency: **{fmt(sim_behav.get('first_chunk_us'))} us**
- Structural simulation (`sim_struct/transcript`):
  - Complete latency: **{fmt(sim_struct.get('complete_cycles'))} cycles**
  - Complete latency: **{fmt(sim_struct.get('complete_ms'))} ms**
- Physical simulation (`sim_phys/transcript`):
  - Complete latency: **{fmt(sim_phys.get('complete_cycles'))} cycles**
  - Complete latency: **{fmt(sim_phys.get('complete_ms'))} ms**

## 2) Timing Metrics (Synthesis + PnR)

### Synthesis Timing (Genus QoR)
- `clk` period: **{fmt(qor.get('clk_period_ps'))} ps**
- `flash_clk` period: **{fmt(qor.get('flash_period_ps'))} ps**
- Worst path slack `clk`: **{fmt(qor.get('clk_slack_ps'))} ps**
- Worst path slack `flash_clk`: **{fmt(qor.get('flash_slack_ps'))} ps**
- Total TNS: **{fmt(qor.get('total_tns'))}**

Source: `synth/reports/struct/et4351_qor.rpt`

### PnR Timing Progression
| Stage / File | Mode | WNS (ns) all | TNS (ns) all | Violating Paths all | DRV (max_tran) |
|---|---|---:|---:|---:|---|
{chr(10).join(timing_rows) if timing_rows else '| N/A | N/A | N/A | N/A | N/A | N/A |'}

### Final Timing Signoff Snapshot
- Setup WNS/TNS/Violating paths: **{fmt(timing_map.get('final_setup', {}).get('wns_all'))} ns / {fmt(timing_map.get('final_setup', {}).get('tns_all'))} ns / {fmt(timing_map.get('final_setup', {}).get('viol_all'))}**
- Hold WNS/TNS/Violating paths: **{fmt(timing_map.get('final_hold', {}).get('wns_all'))} ns / {fmt(timing_map.get('final_hold', {}).get('tns_all'))} ns / {fmt(timing_map.get('final_hold', {}).get('viol_all'))}**
- DRV max_tran (final setup report): **{fmt(timing_map.get('final_setup', {}).get('max_tran_real'))}**, worst **{fmt(timing_map.get('final_setup', {}).get('max_tran_worst'))}**

Sources:
- `pnr/finalReports/report_timing/et4351_postRoute.summary.gz`
- `pnr/finalReports/report_timing_hold/et4351_postRoute_hold.summary.gz`
- `pnr/finalReports/report_DRV/et4351_postRoute.summary.gz`

## 3) Power Metrics (All Available Power Reports)

Power units in reports are **mW**.

| Report file | Internal | Switching | Leakage | Total | Annotation shown in rpt |
|---|---:|---:|---:|---:|---|
{chr(10).join(power_rows) if power_rows else '| N/A | N/A | N/A | N/A | N/A | N/A |'}

### Final Power Breakdown (Hierarchy)
From `{final_power_rel}`:
- `accel` total power: **{fmt(power_hier.get('accel_total'))} mW**
  - internal: {fmt(power_hier.get('accel_internal'))}, switching: {fmt(power_hier.get('accel_switching'))}, leakage: {fmt(power_hier.get('accel_leakage'))}
- `soc` total power: **{fmt(power_hier.get('soc_total'))} mW**
- whole-chip total power: **{fmt(power_map.get(final_power_name, {}).get('total')) if final_power_name else 'N/A'} mW**
- clock network power (`clk`): **{fmt(power_hier.get('clk_total'))} mW**
- clock period used in report: **{fmt(power_map.get(final_power_name, {}).get('clock_period_usec')) if final_power_name else 'N/A'} usec**
- clock toggle rate used in report: **{fmt(power_map.get(final_power_name, {}).get('clock_toggle_mhz')) if final_power_name else 'N/A'} MHz**

### Energy (using first-chunk latency from behavioral sim)
Using `T_chunk = {fmt(sim_behav.get('first_chunk_us'))} us`:
- Accelerator-only chunk energy: **{f"{accel_energy:.3f}" if accel_energy is not None else "N/A"} nJ**
- Whole-chip chunk energy: **{f"{chip_energy:.3f}" if chip_energy is not None else "N/A"} nJ**

## 4) Activity Annotation Notes

- Power report headers often show `Design annotation coverage: 0/... = 0%`.
- Innovus log VCD import section:
  - annotation source log: **{innovus_log_rel}**
  - per-file coverage: **{fmt(ann_log.get('coverage_file'))}**
  - total coverage: **{fmt(ann_log.get('coverage_total'))}**
  - zero-toggle fraction: **{fmt(ann_log.get('zero_toggle'))}**
  - nets in VCD but not design: **{fmt(ann_log.get('missing_nets'))}**

Sources: `{innovus_log_rel}`, `pnr/voltus_power_missing_netnames.rpt`

## 5) Area and Signoff-Related Status

### Area
- Synthesis total area (Cell+Net): **{fmt(areas.get('synth_total_area'))}**
- Synthesis total cell area: **{fmt(areas.get('synth_cell_area'))}**
- Final placed design total area: **{fmt(areas.get('final_total_area'))}**

Sources:
- `synth/reports/struct/et4351_area.rpt`
- `pnr/finalReports/report_area.rpt`

### Signoff/Verification reports
- DRC: **{fmt(signoff.get('drc'))}**
- Connectivity: **{fmt(signoff.get('connectivity'))}**
- Antenna: **{fmt(signoff.get('antenna'))}**
- Placement check: **{fmt(signoff.get('place'))}**
- CTS timing-check warnings:
  - ideal_clock_waveform: **{fmt(signoff.get('cts_warning_ideal_clock'))}**
  - no_input_delay: **{fmt(signoff.get('cts_warning_no_input_delay'))}**
  - unconstrained endpoint: **{fmt(signoff.get('cts_warning_uncons_endpoint'))}**

## 6) Comparison Vs Hardcoded Baselines

Both baseline references are embedded in this script:
- Legacy baseline: non-windowed post-layout power (`report_power.rpt`)
- Windowed baseline: post-route VCD-windowed power (`report_power_postRouteVCD.rpt`)

### 6.1 Legacy Baseline Comparison
Current-run power source used for this comparison: {legacy_source}

| Metric | Current run | Legacy baseline | Delta (current-baseline) | Status |
|---|---:|---:|---:|---|
{chr(10).join(comparison_rows_legacy_md)}

### 6.2 Windowed Baseline Comparison
Current-run power source used for this comparison: {windowed_source}

| Metric | Current run | Windowed baseline | Delta (current-baseline) | Status |
|---|---:|---:|---:|---|
{chr(10).join(comparison_rows_windowed_md)}

## 7) ET4351 Project Description Checklist

Checklist derived from `instructions/ET4351_2026_Project_Description.pdf` (Section 1.1 and related “Important Things” requirements).

| Requirement (Project Description) | Result | Evidence |
|---|---|---|
{chr(10).join(project_desc_rows_md)}
"""


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate baseline metrics markdown from run reports.")
    parser.add_argument(
        "--root",
        type=Path,
        default=Path("."),
        help="Run folder root (default: current directory)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("all_metrics.md"),
        help="Output markdown path (default: all_metrics.md)",
    )
    args = parser.parse_args()

    root = args.root.resolve()
    output = args.output if args.output.is_absolute() else root / args.output
    md = build_markdown(root)
    output.write_text(md)
    print(f"Wrote: {output}")


if __name__ == "__main__":
    main()
