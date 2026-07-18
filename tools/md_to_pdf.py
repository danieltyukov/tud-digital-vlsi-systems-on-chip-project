#!/usr/bin/env python3
"""Convert markdown files to PDF using fpdf2."""
import sys
import re
from fpdf import FPDF


class MarkdownPDF(FPDF):
    def __init__(self):
        super().__init__()
        self.add_font("DejaVu", "", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")
        self.add_font("DejaVu", "B", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf")
        self.add_font("DejaVu", "I", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Oblique.ttf")
        self.set_auto_page_break(auto=True, margin=15)
        self.set_font("DejaVu", size=9)

    def header(self):
        pass

    def footer(self):
        self.set_y(-15)
        self.set_font("DejaVu", "I", 7)
        self.cell(0, 10, f"Page {self.page_no()}", align="C")


def clean_md(text):
    """Strip markdown inline formatting."""
    text = re.sub(r'\*\*(.*?)\*\*', r'\1', text)
    text = re.sub(r'\*(.*?)\*', r'\1', text)
    text = re.sub(r'`(.*?)`', r'\1', text)
    return text


def md_to_pdf(md_path, pdf_path):
    with open(md_path, "r", encoding="utf-8") as f:
        text = f.read()

    pdf = MarkdownPDF()
    pdf.add_page()
    lh = 4.5  # line height
    margin = 10
    pdf.set_left_margin(margin)
    pdf.set_right_margin(margin)
    pw = pdf.w - 2 * margin  # usable page width

    lines = text.split("\n")
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        i += 1

        # Skip empty lines
        if not stripped:
            pdf.ln(2)
            continue

        # Horizontal rules — thin gray line, compact spacing
        if stripped in ("---", "***", "___"):
            pdf.ln(1)
            y = pdf.get_y()
            pdf.set_draw_color(180, 180, 180)
            pdf.line(margin, y, pdf.w - margin, y)
            pdf.set_draw_color(0, 0, 0)
            pdf.ln(2)
            continue

        # H1
        if stripped.startswith("# ") and not stripped.startswith("##"):
            pdf.ln(2)
            pdf.set_font("DejaVu", "B", 14)
            pdf.multi_cell(pw, lh + 3, stripped.lstrip("#").strip())
            pdf.ln(2)
            pdf.set_font("DejaVu", size=9)
            continue

        # H2
        if stripped.startswith("## ") and not stripped.startswith("###"):
            pdf.ln(2)
            pdf.set_font("DejaVu", "B", 11)
            pdf.multi_cell(pw, lh + 2, stripped.lstrip("#").strip())
            pdf.ln(1)
            pdf.set_font("DejaVu", size=9)
            continue

        # H3
        if stripped.startswith("### "):
            pdf.ln(1)
            pdf.set_font("DejaVu", "B", 10)
            pdf.multi_cell(pw, lh + 1, stripped.lstrip("#").strip())
            pdf.ln(1)
            pdf.set_font("DejaVu", size=9)
            continue

        # Table separator — skip
        if re.match(r'^[\|\s\-:]+$', stripped) and '|' in stripped:
            continue

        # Table rows
        if '|' in stripped:
            cells = [c.strip() for c in stripped.split("|")]
            cells = [c for c in cells if c]
            if cells:
                col_w = pw / max(len(cells), 1)
                pdf.set_font("DejaVu", size=8)
                for cell in cells:
                    pdf.cell(col_w, lh + 1, clean_md(cell)[:60], border=1)
                pdf.ln()
                pdf.set_font("DejaVu", size=9)
            continue

        # Bullet points
        if stripped.startswith("- ") or stripped.startswith("* "):
            content = clean_md(stripped[2:])
            indent = 4
            pdf.set_x(margin + indent)
            pdf.multi_cell(pw - indent, lh, "\u2022  " + content)
            continue

        # Regular text
        pdf.multi_cell(pw, lh, clean_md(stripped))

    pdf.output(pdf_path)
    print(f"Created: {pdf_path}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 md_to_pdf.py input.md output.pdf")
        sys.exit(1)
    md_to_pdf(sys.argv[1], sys.argv[2])
