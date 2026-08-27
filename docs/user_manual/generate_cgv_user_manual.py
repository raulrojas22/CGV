#!/usr/bin/env python3
"""Build the CGeV Web and Desktop user manual as a publication-ready PDF."""

from __future__ import annotations

import csv
import html
import json
import math
import re
import shutil
import sys
from pathlib import Path
from typing import List, Sequence

from reportlab.graphics.shapes import Drawing, Line, Polygon, Rect, String
from reportlab.lib import colors
from reportlab.lib.colors import HexColor
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    BaseDocTemplate,
    CondPageBreak,
    Flowable,
    Frame,
    HRFlowable,
    Image,
    KeepTogether,
    LongTable,
    NextPageTemplate,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)
from reportlab.platypus.tableofcontents import TableOfContents


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "docs" / "user_manual" / "CGeV_User_Manual_Source.md"
REGISTRY = ROOT / "annotations" / "registry.tsv"
APP_ICON = ROOT / "desktop" / "build" / "icon.png"
SCREENSHOT_DIR = ROOT / "docs" / "user_manual" / "assets" / "screenshots"
CONFIG_PATH = ROOT / "docs" / "user_manual" / "manual_config.json"
CONFIG = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
MANUAL_VERSION = str(CONFIG["manual_version"])
PRODUCT_VERSION = str(CONFIG["product_version"])
REVISION_DATE = str(CONFIG["revision_date"])
REVISION_DISPLAY = str(CONFIG["revision_display"])
PUBLIC_FILENAME = str(CONFIG["public_filename"])
VERSIONED_FILENAME = f"CGeV_User_Manual_Web_and_Desktop_v{MANUAL_VERSION}.pdf"
OUTPUT = ROOT / "output" / "pdf" / VERSIONED_FILENAME
PUBLIC_LATEST = ROOT / "www" / "docs" / PUBLIC_FILENAME
LEGACY_PUBLIC_LATEST = ROOT / "www" / "docs" / "CGV_User_Manual.pdf"
PUBLIC_ARCHIVE = ROOT / "www" / "docs" / "archive" / VERSIONED_FILENAME
PUBLIC_METADATA = ROOT / "www" / "docs" / "manual.json"

PAGE_W, PAGE_H = A4
LEFT = 17 * mm
RIGHT = 15 * mm
TOP = 19 * mm
BOTTOM = 17 * mm
CONTENT_W = PAGE_W - LEFT - RIGHT

NAVY = HexColor("#17263B")
NAVY_2 = HexColor("#233750")
TEAL = HexColor("#18BFA5")
TEAL_DARK = HexColor("#0B8C7A")
MINT = HexColor("#DDF7F1")
BLUE = HexColor("#2F77A8")
SKY = HexColor("#EAF4FA")
GOLD = HexColor("#D8A52E")
INK = HexColor("#24313D")
MUTED = HexColor("#657482")
PALE = HexColor("#F4F7F8")
LINE_C = HexColor("#D9E2E6")
WHITE = colors.white


def register_fonts() -> None:
    global FONT, FONT_BOLD, FONT_ITALIC, FONT_BOLD_ITALIC
    font_dir = Path("/System/Library/Fonts/Supplemental")
    candidates = {
        "CGVSans": font_dir / "Arial.ttf",
        "CGVSans-Bold": font_dir / "Arial Bold.ttf",
        "CGVSans-Italic": font_dir / "Arial Italic.ttf",
        "CGVSans-BoldItalic": font_dir / "Arial Bold Italic.ttf",
    }
    if all(path.exists() for path in candidates.values()):
        for name, path in candidates.items():
            pdfmetrics.registerFont(TTFont(name, str(path)))
        pdfmetrics.registerFontFamily(
            "CGVSans",
            normal="CGVSans",
            bold="CGVSans-Bold",
            italic="CGVSans-Italic",
            boldItalic="CGVSans-BoldItalic",
        )
        FONT = "CGVSans"
        FONT_BOLD = "CGVSans-Bold"
        FONT_ITALIC = "CGVSans-Italic"
        FONT_BOLD_ITALIC = "CGVSans-BoldItalic"
    else:
        FONT = "Helvetica"
        FONT_BOLD = "Helvetica-Bold"
        FONT_ITALIC = "Helvetica-Oblique"
        FONT_BOLD_ITALIC = "Helvetica-BoldOblique"


register_fonts()


def make_styles():
    sample = getSampleStyleSheet()
    styles = {}
    styles["Body"] = ParagraphStyle(
        "Body",
        parent=sample["BodyText"],
        fontName=FONT,
        fontSize=8.65,
        leading=12.25,
        textColor=INK,
        alignment=TA_JUSTIFY,
        spaceAfter=5.3,
        splitLongWords=True,
        allowWidows=0,
        allowOrphans=0,
    )
    styles["Lead"] = ParagraphStyle(
        "Lead",
        parent=styles["Body"],
        fontSize=10.2,
        leading=14.4,
        textColor=NAVY_2,
        alignment=TA_JUSTIFY,
        spaceAfter=9,
    )
    styles["Heading1"] = ParagraphStyle(
        "Heading1",
        parent=sample["Heading1"],
        fontName=FONT_BOLD,
        fontSize=20,
        leading=23,
        textColor=NAVY,
        spaceBefore=0,
        spaceAfter=5,
        keepWithNext=True,
    )
    styles["Heading2"] = ParagraphStyle(
        "Heading2",
        parent=sample["Heading2"],
        fontName=FONT_BOLD,
        fontSize=12.1,
        leading=15,
        textColor=TEAL_DARK,
        spaceBefore=10,
        spaceAfter=4,
        keepWithNext=True,
    )
    styles["Heading3"] = ParagraphStyle(
        "Heading3",
        parent=sample["Heading3"],
        fontName=FONT_BOLD,
        fontSize=9.6,
        leading=12,
        textColor=NAVY_2,
        spaceBefore=7,
        spaceAfter=3,
        keepWithNext=True,
    )
    styles["Bullet"] = ParagraphStyle(
        "Bullet",
        parent=styles["Body"],
        leftIndent=13,
        firstLineIndent=-7,
        bulletIndent=2,
        bulletColor=TEAL_DARK,
        spaceAfter=2.8,
    )
    styles["Number"] = ParagraphStyle(
        "Number",
        parent=styles["Body"],
        leftIndent=16,
        firstLineIndent=-12,
        bulletIndent=1,
        bulletColor=TEAL_DARK,
        spaceAfter=3,
    )
    styles["Table"] = ParagraphStyle(
        "Table",
        parent=styles["Body"],
        fontSize=7.35,
        leading=9.4,
        alignment=TA_LEFT,
        spaceAfter=0,
    )
    styles["TableHead"] = ParagraphStyle(
        "TableHead",
        parent=styles["Table"],
        fontName=FONT_BOLD,
        textColor=WHITE,
        leading=9.2,
    )
    styles["Callout"] = ParagraphStyle(
        "Callout",
        parent=styles["Body"],
        fontSize=8.2,
        leading=11.6,
        textColor=NAVY_2,
        leftIndent=1,
        rightIndent=1,
        alignment=TA_JUSTIFY,
        spaceAfter=0,
    )
    styles["Caption"] = ParagraphStyle(
        "Caption",
        parent=styles["Body"],
        fontName=FONT_ITALIC,
        fontSize=7.25,
        leading=9.5,
        textColor=MUTED,
        alignment=TA_LEFT,
        spaceBefore=4,
        spaceAfter=0,
    )
    styles["TOCTitle"] = ParagraphStyle(
        "TOCTitle",
        parent=styles["Heading1"],
        fontSize=23,
        leading=27,
        spaceAfter=5,
    )
    styles["TOC0"] = ParagraphStyle(
        "TOC0",
        fontName=FONT_BOLD,
        fontSize=8.25,
        leading=11,
        textColor=NAVY,
        leftIndent=0,
        firstLineIndent=0,
        spaceBefore=1.5,
    )
    styles["TOC1"] = ParagraphStyle(
        "TOC1",
        fontName=FONT,
        fontSize=6.8,
        leading=8.65,
        textColor=MUTED,
        leftIndent=12,
        firstLineIndent=0,
        spaceBefore=0,
    )
    return styles


STYLES = make_styles()


class CoverMarker(Flowable):
    def wrap(self, avail_width, avail_height):
        return 1, 1

    def draw(self):
        pass


class ManualDocTemplate(BaseDocTemplate):
    """Document template with PDF outlines and a two-level table of contents."""

    def __init__(self, filename: str, **kwargs):
        super().__init__(filename, **kwargs)
        self._heading_counter = 0

    def beforeDocument(self):
        # multiBuild performs several passes; stable keys allow the TOC to converge.
        self._heading_counter = 0

    def afterFlowable(self, flowable):
        if not isinstance(flowable, Paragraph):
            return
        style_name = flowable.style.name
        if style_name not in ("Heading1", "Heading2"):
            return
        level = 0 if style_name == "Heading1" else 1
        text = flowable.getPlainText()
        self._heading_counter += 1
        key = f"heading-{self._heading_counter}"
        self.canv.bookmarkPage(key)
        self.canv.addOutlineEntry(text, key, level=level, closed=(level == 0))
        self.notify("TOCEntry", (level, text, self.page, key))


def draw_cover(canvas, doc):
    canvas.saveState()
    canvas.setFillColor(NAVY)
    canvas.rect(0, 0, PAGE_W, PAGE_H, fill=1, stroke=0)

    canvas.setFillColor(NAVY_2)
    canvas.circle(PAGE_W + 12 * mm, PAGE_H - 42 * mm, 57 * mm, fill=1, stroke=0)
    canvas.setFillColor(HexColor("#1B3049"))
    canvas.circle(-16 * mm, 29 * mm, 48 * mm, fill=1, stroke=0)

    x0, y0, motif_w = 37 * mm, PAGE_H - 50 * mm, 137 * mm
    canvas.setLineWidth(1.6)
    for i in range(33):
        t = i / 32
        x = x0 + t * motif_w
        y_a = y0 + math.sin(t * math.pi * 4) * 10 * mm
        y_b = y0 - math.sin(t * math.pi * 4) * 10 * mm
        canvas.setStrokeColor(TEAL if i % 2 else HexColor("#607B96"))
        canvas.line(x, y_a, x, y_b)
    canvas.setLineWidth(3)
    points_a, points_b = [], []
    for i in range(100):
        t = i / 99
        x = x0 + t * motif_w
        points_a.append((x, y0 + math.sin(t * math.pi * 4) * 10 * mm))
        points_b.append((x, y0 - math.sin(t * math.pi * 4) * 10 * mm))
    for points, color in ((points_a, TEAL), (points_b, HexColor("#9FB3C4"))):
        canvas.setStrokeColor(color)
        path = canvas.beginPath()
        path.moveTo(*points[0])
        for point in points[1:]:
            path.lineTo(*point)
        canvas.drawPath(path, stroke=1, fill=0)

    if APP_ICON.exists():
        canvas.drawImage(
            str(APP_ICON),
            20 * mm,
            PAGE_H - 40 * mm,
            width=22 * mm,
            height=22 * mm,
            preserveAspectRatio=True,
            mask="auto",
        )

    canvas.setFillColor(WHITE)
    canvas.setFont(FONT_BOLD, 10)
    canvas.drawString(47 * mm, PAGE_H - 26 * mm, "COMPARATIVE GENE VIEWER")

    canvas.setFillColor(TEAL)
    canvas.roundRect(20 * mm, PAGE_H - 103 * mm, 39 * mm, 7 * mm, 3.5 * mm, fill=1, stroke=0)
    canvas.setFillColor(NAVY)
    canvas.setFont(FONT_BOLD, 7.2)
    canvas.drawCentredString(39.5 * mm, PAGE_H - 100.7 * mm, "OFFICIAL MANUAL")

    canvas.setFillColor(WHITE)
    canvas.setFont(FONT_BOLD, 34)
    canvas.drawString(20 * mm, PAGE_H - 127 * mm, "CGeV User Manual")
    canvas.setFont(FONT, 17)
    canvas.setFillColor(HexColor("#C9D6DF"))
    canvas.drawString(20 * mm, PAGE_H - 140 * mm, "Web and Desktop Edition")

    canvas.setStrokeColor(TEAL)
    canvas.setLineWidth(2)
    canvas.line(20 * mm, PAGE_H - 151 * mm, 73 * mm, PAGE_H - 151 * mm)

    canvas.setFillColor(WHITE)
    canvas.setFont(FONT, 10.2)
    canvas.drawString(20 * mm, PAGE_H - 165 * mm, "Search  |  Compare  |  Interpret  |  Export")

    canvas.setFillColor(HexColor("#B8C8D5"))
    canvas.setFont(FONT, 8.4)
    text = canvas.beginText(20 * mm, PAGE_H - 181 * mm)
    text.setLeading(12)
    text.textLine("A complete operational and interpretive reference for gene-centered")
    text.textLine("visualization, comparative analysis, functional context, and publication output.")
    canvas.drawText(text)

    canvas.setFillColor(HexColor("#1E344D"))
    canvas.roundRect(20 * mm, 24 * mm, PAGE_W - 40 * mm, 27 * mm, 4 * mm, fill=1, stroke=0)
    canvas.setFillColor(TEAL)
    canvas.setFont(FONT_BOLD, 7.4)
    canvas.drawString(27 * mm, 42 * mm, "VERSION")
    canvas.drawString(77 * mm, 42 * mm, "REVISION")
    canvas.drawString(133 * mm, 42 * mm, "APPLICATION")
    canvas.setFillColor(WHITE)
    canvas.setFont(FONT, 8.6)
    canvas.drawString(27 * mm, 33 * mm, MANUAL_VERSION)
    canvas.drawString(77 * mm, 33 * mm, REVISION_DISPLAY)
    canvas.drawString(133 * mm, 33 * mm, "cgv.mobilomics.org")
    canvas.restoreState()


def draw_content_page(canvas, doc):
    canvas.saveState()
    canvas.setStrokeColor(LINE_C)
    canvas.setLineWidth(0.55)
    canvas.line(LEFT, PAGE_H - 12.5 * mm, PAGE_W - RIGHT, PAGE_H - 12.5 * mm)
    canvas.setFillColor(NAVY)
    canvas.setFont(FONT_BOLD, 7.1)
    canvas.drawString(LEFT, PAGE_H - 9.5 * mm, "CGeV USER MANUAL")
    canvas.setFillColor(MUTED)
    canvas.setFont(FONT, 7.1)
    canvas.drawRightString(
        PAGE_W - RIGHT,
        PAGE_H - 9.5 * mm,
        f"WEB AND DESKTOP  |  VERSION {MANUAL_VERSION}",
    )

    canvas.setStrokeColor(LINE_C)
    canvas.line(LEFT, 10.5 * mm, PAGE_W - RIGHT, 10.5 * mm)
    canvas.setFillColor(MUTED)
    canvas.setFont(FONT, 6.8)
    canvas.drawString(LEFT, 6.6 * mm, "Comparative Gene Viewer")
    canvas.drawRightString(PAGE_W - RIGHT, 6.6 * mm, f"{doc.page}")
    canvas.restoreState()


def inline_markup(text: str) -> str:
    """Convert the small Markdown subset used in the source to Paragraph XML."""
    escaped = html.escape(text, quote=False)
    code_tokens = {}

    def stash_code(match):
        key = f"@@CODE{len(code_tokens)}@@"
        code_tokens[key] = (
            f'<font name="Courier" color="#24465F" backColor="#EDF3F6">'
            f"{match.group(1)}</font>"
        )
        return key

    escaped = re.sub(r"`([^`]+)`", stash_code, escaped)
    escaped = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", escaped)
    escaped = re.sub(r"(?<!\*)\*([^*]+)\*(?!\*)", r"<i>\1</i>", escaped)
    escaped = re.sub(
        r"(?<![\"'=])(https?://[^\s<]+)",
        r'<link href="\1" color="#0B7F72">\1</link>',
        escaped,
    )
    for key, replacement in code_tokens.items():
        escaped = escaped.replace(key, replacement)
    return escaped


def weighted_column_widths(rows: Sequence[Sequence[str]], total: float) -> List[float]:
    col_count = len(rows[0])
    weights = []
    for c in range(col_count):
        lengths = [min(len(re.sub(r"[*`]", "", row[c])), 70) for row in rows if c < len(row)]
        weights.append(max(8, sum(lengths) / max(len(lengths), 1)))
    raw = [w / sum(weights) for w in weights]
    minimum = 0.14 if col_count <= 4 else 0.1
    raw = [max(minimum, min(0.48, x)) for x in raw]
    scale = 1 / sum(raw)
    return [total * x * scale for x in raw]


def build_table(rows: Sequence[Sequence[str]], widths=None, compact=False):
    if not rows:
        return Spacer(1, 1)
    col_count = max(len(row) for row in rows)
    clean_rows = [list(row) + [""] * (col_count - len(row)) for row in rows]
    widths = widths or weighted_column_widths(clean_rows, CONTENT_W)
    data = []
    for r, row in enumerate(clean_rows):
        style = STYLES["TableHead"] if r == 0 else STYLES["Table"]
        data.append([Paragraph(inline_markup(cell), style) for cell in row])
    table = LongTable(
        data,
        colWidths=widths,
        repeatRows=1,
        hAlign="LEFT",
        splitByRow=1,
        spaceBefore=4,
        spaceAfter=8,
    )
    padding_v = 3.2 if compact else 4.1
    commands = [
        ("BACKGROUND", (0, 0), (-1, 0), NAVY_2),
        ("TEXTCOLOR", (0, 0), (-1, 0), WHITE),
        ("FONTNAME", (0, 0), (-1, 0), FONT_BOLD),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), padding_v),
        ("BOTTOMPADDING", (0, 0), (-1, -1), padding_v),
        ("LINEBELOW", (0, 0), (-1, 0), 1, TEAL),
        ("GRID", (0, 0), (-1, -1), 0.35, LINE_C),
    ]
    for r in range(1, len(data)):
        commands.append(("BACKGROUND", (0, r), (-1, r), WHITE if r % 2 else PALE))
    table.setStyle(TableStyle(commands))
    return table


def build_callout(text: str):
    label = "NOTE"
    body = text.strip()
    match = re.match(r"^(IMPORTANT|NOTE|TIP):\s*(.*)$", body)
    if match:
        label, body = match.groups()
    palette = {
        "IMPORTANT": (HexColor("#FFF3D4"), GOLD),
        "NOTE": (SKY, BLUE),
        "TIP": (MINT, TEAL_DARK),
    }
    bg, accent = palette[label]
    label_style = ParagraphStyle(
        f"{label}Label",
        parent=STYLES["Callout"],
        fontName=FONT_BOLD,
        fontSize=7.2,
        leading=8.6,
        textColor=accent,
        alignment=TA_LEFT,
        splitLongWords=False,
    )
    label_cell = Paragraph(label, label_style)
    body_cell = Paragraph(inline_markup(body), STYLES["Callout"])
    label_width = 30 * mm
    table = Table([[label_cell, body_cell]], colWidths=[label_width, CONTENT_W - label_width])
    table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), bg),
        ("BOX", (0, 0), (-1, -1), 0.45, accent),
        ("LINEBEFORE", (0, 0), (0, -1), 3, accent),
        ("VALIGN", (0, 0), (0, -1), "MIDDLE"),
        ("VALIGN", (1, 0), (1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 7),
        ("RIGHTPADDING", (0, 0), (-1, -1), 7),
        ("TOPPADDING", (0, 0), (-1, -1), 7),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
    ]))
    return KeepTogether([Spacer(1, 2), table, Spacer(1, 7)])


def draw_paragraph(canvas, paragraph, x, top, width, max_height):
    """Draw a wrapped paragraph using a top-left anchor."""
    _, height = paragraph.wrap(width, max_height)
    paragraph.drawOn(canvas, x, top - height)
    return height


class WorkflowDiagram(Flowable):
    """Five-step workflow rendered with true wrapped paragraphs."""

    height = 200

    def wrap(self, avail_width, avail_height):
        self.width = min(avail_width, CONTENT_W)
        return self.width, self.height

    def draw(self):
        c = self.canv
        width = self.width
        c.saveState()
        c.setFillColor(PALE)
        c.setStrokeColor(LINE_C)
        c.roundRect(0, 0, width, self.height, 8, fill=1, stroke=1)

        title_style = ParagraphStyle(
            "WorkflowLabel",
            fontName=FONT_BOLD,
            fontSize=8,
            leading=9.5,
            textColor=TEAL_DARK,
            alignment=TA_LEFT,
        )
        box_title_style = ParagraphStyle(
            "WorkflowBoxTitle",
            fontName=FONT_BOLD,
            fontSize=6.85,
            leading=8.2,
            textColor=WHITE,
            alignment=TA_CENTER,
            splitLongWords=False,
        )
        box_detail_style = ParagraphStyle(
            "WorkflowBoxDetail",
            fontName=FONT,
            fontSize=6.05,
            leading=8.05,
            textColor=HexColor("#E8F1F5"),
            alignment=TA_CENTER,
            splitLongWords=False,
        )
        footer_style = ParagraphStyle(
            "WorkflowFooter",
            fontName=FONT,
            fontSize=6.65,
            leading=8.3,
            textColor=MUTED,
            alignment=TA_CENTER,
        )
        draw_paragraph(c, Paragraph("THE CGeV ANALYSIS PATH", title_style), 12, 182, width - 24, 16)

        labels = [
            ("1", "SELECT<br/>WORKFLOW", "One organism with many genes, or many organisms with one gene."),
            ("2", "PREPARE<br/>DATA", "Use preloaded data, NCBI Search, uploaded files, or mixed sources."),
            ("3", "GENERATE", "Resolve identifiers and build the interactive result cards."),
            ("4", "ANALYZE", "Inspect structure, alignments, metrics, function, context, and literature."),
            ("5", "PRESERVE", "Export SVG, PNG, CSV, FASTA, and the complete RDS session."),
        ]
        outer = 12
        gap = 8
        box_w = (width - 2 * outer - 4 * gap) / 5
        box_y = 43
        box_h = 116

        for i, (num, title, detail) in enumerate(labels):
            x = outer + i * (box_w + gap)
            fill = NAVY_2 if i in (0, 2, 4) else TEAL_DARK
            c.setFillColor(fill)
            c.setStrokeColor(fill)
            c.roundRect(x, box_y, box_w, box_h, 6, fill=1, stroke=0)

            c.setFillColor(WHITE)
            c.circle(x + box_w / 2, box_y + box_h - 17, 9, fill=1, stroke=0)
            c.setFillColor(fill)
            c.setFont(FONT_BOLD, 7.5)
            c.drawCentredString(x + box_w / 2, box_y + box_h - 19.6, num)

            title_p = Paragraph(title, box_title_style)
            draw_paragraph(c, title_p, x + 7, box_y + box_h - 35, box_w - 14, 28)
            detail_p = Paragraph(detail, box_detail_style)
            draw_paragraph(c, detail_p, x + 7, box_y + 61, box_w - 14, 52)

            if i < 4:
                arrow_x = x + box_w + 1.5
                arrow_y = box_y + box_h / 2
                c.setFillColor(TEAL)
                c.setStrokeColor(TEAL)
                c.line(arrow_x, arrow_y, arrow_x + gap - 4, arrow_y)
                path = c.beginPath()
                path.moveTo(arrow_x + gap - 4, arrow_y + 3)
                path.lineTo(arrow_x + gap, arrow_y)
                path.lineTo(arrow_x + gap - 4, arrow_y - 3)
                path.close()
                c.drawPath(path, fill=1, stroke=0)

        footer = Paragraph(
            "Verify source provenance and the resolved gene or transcript before interpreting differences.",
            footer_style,
        )
        draw_paragraph(c, footer, 18, 24, width - 36, 18)
        c.restoreState()


class InterfaceMap(Flowable):
    """Schematic interface map with separated labels and wrapped content."""

    height = 232

    def wrap(self, avail_width, avail_height):
        self.width = min(avail_width, CONTENT_W)
        return self.width, self.height

    def draw(self):
        c = self.canv
        width = self.width
        c.saveState()
        c.setFillColor(HexColor("#EEF3F5"))
        c.setStrokeColor(LINE_C)
        c.roundRect(0, 0, width, self.height, 8, fill=1, stroke=1)

        sidebar_x, sidebar_y, sidebar_w, sidebar_h = 10, 12, 112, 208
        c.setFillColor(NAVY)
        c.roundRect(sidebar_x, sidebar_y, sidebar_w, sidebar_h, 5, fill=1, stroke=0)

        sidebar_title = ParagraphStyle(
            "InterfaceSidebarTitle",
            fontName=FONT_BOLD,
            fontSize=7.7,
            leading=9,
            textColor=TEAL,
            alignment=TA_CENTER,
        )
        sidebar_item = ParagraphStyle(
            "InterfaceSidebarItem",
            fontName=FONT,
            fontSize=6.35,
            leading=7.3,
            textColor=WHITE,
            alignment=TA_CENTER,
        )
        draw_paragraph(
            c,
            Paragraph("LEFT SIDEBAR", sidebar_title),
            sidebar_x + 8,
            sidebar_y + sidebar_h - 15,
            sidebar_w - 16,
            14,
        )
        items = [
            "Home",
            "Multi-Gene Search",
            "Cross-Species Search",
            "Figure Studio",
            "CGeV Guide",
            "Settings / Feedback",
        ]
        for i, item in enumerate(items):
            y = sidebar_y + sidebar_h - 48 - i * 25
            c.setFillColor(NAVY_2)
            c.setStrokeColor(HexColor("#425970"))
            c.roundRect(sidebar_x + 10, y, sidebar_w - 20, 18, 3, fill=1, stroke=1)
            draw_paragraph(
                c,
                Paragraph(item, sidebar_item),
                sidebar_x + 15,
                y + 12.5,
                sidebar_w - 30,
                13,
            )

        main_x = 134
        main_w = width - main_x - 10
        main_title = ParagraphStyle(
            "InterfaceMainTitle",
            fontName=FONT_BOLD,
            fontSize=8,
            leading=9.5,
            textColor=NAVY,
            alignment=TA_LEFT,
        )
        draw_paragraph(c, Paragraph("MAIN WORKSPACE", main_title), main_x, 215, main_w, 14)

        section_title = ParagraphStyle(
            "InterfaceSectionTitle",
            fontName=FONT_BOLD,
            fontSize=7.15,
            leading=8.5,
            alignment=TA_LEFT,
        )
        section_detail = ParagraphStyle(
            "InterfaceSectionDetail",
            fontName=FONT,
            fontSize=6.45,
            leading=7.7,
            textColor=MUTED,
            alignment=TA_LEFT,
        )
        sections = [
            (165, 36, TEAL_DARK, "CONTEXT HEADER", "Workflow, organisms, current query, notifications, and display modes."),
            (120, 36, BLUE, "RESULT TOOLBAR", "Summary, CSV, analytics, batch SVG, sorting, and zoom."),
            (54, 56, NAVY_2, "INTERACTIVE RESULT CARDS", "Card header, gene model, transcript statistics, and analysis actions."),
            (10, 34, HexColor("#536A7E"), "ANALYSIS AND EXPORT", "Analytics, alignment views, Figure Studio, and sessions."),
        ]
        for y, h, accent, title, detail in sections:
            c.setFillColor(WHITE)
            c.setStrokeColor(LINE_C)
            c.roundRect(main_x, y, main_w, h, 5, fill=1, stroke=1)
            c.setFillColor(accent)
            c.roundRect(main_x, y, 8, h, 4, fill=1, stroke=0)

            title_style = section_title.clone(f"{title}Style")
            title_style.textColor = accent
            draw_paragraph(c, Paragraph(title, title_style), main_x + 18, y + h - 9, main_w - 28, 12)
            draw_paragraph(
                c,
                Paragraph(detail, section_detail),
                main_x + 18,
                y + h - 21,
                main_w - 28,
                h - 22,
            )
        c.restoreState()


def workflow_diagram():
    title_style = ParagraphStyle(
        "WorkflowTableTitle",
        fontName=FONT_BOLD,
        fontSize=8,
        leading=9.5,
        textColor=TEAL_DARK,
        alignment=TA_LEFT,
    )
    number_style = ParagraphStyle(
        "WorkflowTableNumber",
        fontName=FONT_BOLD,
        fontSize=8,
        leading=10,
        textColor=WHITE,
        alignment=TA_CENTER,
    )
    box_title_style = ParagraphStyle(
        "WorkflowTableBoxTitle",
        fontName=FONT_BOLD,
        fontSize=6.75,
        leading=8,
        textColor=WHITE,
        alignment=TA_CENTER,
        splitLongWords=False,
    )
    box_detail_style = ParagraphStyle(
        "WorkflowTableBoxDetail",
        fontName=FONT,
        fontSize=5.95,
        leading=7.6,
        textColor=HexColor("#E8F1F5"),
        alignment=TA_CENTER,
        splitLongWords=False,
    )
    footer_style = ParagraphStyle(
        "WorkflowTableFooter",
        fontName=FONT,
        fontSize=6.6,
        leading=8,
        textColor=MUTED,
        alignment=TA_CENTER,
    )
    arrow_style = ParagraphStyle(
        "WorkflowArrow",
        fontName=FONT_BOLD,
        fontSize=15,
        leading=16,
        textColor=TEAL,
        alignment=TA_CENTER,
    )
    labels = [
        ("1", "SELECT<br/>WORKFLOW", "One organism with many genes, or many organisms with one gene."),
        ("2", "PREPARE<br/>DATA", "Use preloaded data, NCBI Search, uploaded files, or mixed sources."),
        ("3", "GENERATE", "Resolve identifiers and build the interactive result cards."),
        ("4", "ANALYZE", "Inspect structure, alignments, metrics, function, context, and literature."),
        ("5", "PRESERVE", "Export SVG, PNG, CSV, FASTA, and the complete RDS session."),
    ]
    available_for_boxes = CONTENT_W - 4 * 10
    box_w = available_for_boxes / 5
    cells = []
    box_indices = []
    for i, (number, title, detail) in enumerate(labels):
        box = Table(
            [
                [Paragraph(number, number_style)],
                [Paragraph(title, box_title_style)],
                [Paragraph(detail, box_detail_style)],
            ],
            colWidths=[box_w],
            rowHeights=[20, 25, 63],
        )
        fill = NAVY_2 if i in (0, 2, 4) else TEAL_DARK
        box.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, -1), fill),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ("LEFTPADDING", (0, 0), (-1, -1), 6),
            ("RIGHTPADDING", (0, 0), (-1, -1), 6),
            ("TOPPADDING", (0, 0), (-1, -1), 2),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 2),
        ]))
        cells.append(box)
        box_indices.append(len(cells) - 1)
        if i < 4:
            cells.append(Paragraph("›", arrow_style))

    col_widths = []
    for i in range(9):
        col_widths.append(box_w if i % 2 == 0 else 10)
    outer = Table(
        [
            [Paragraph("THE CGeV ANALYSIS PATH", title_style)] + [""] * 8,
            cells,
            [Paragraph(
                "Verify source provenance and the resolved gene or transcript before interpreting differences.",
                footer_style,
            )] + [""] * 8,
        ],
        colWidths=col_widths,
        rowHeights=[27, 108, 27],
        hAlign="CENTER",
    )
    style_commands = [
        ("SPAN", (0, 0), (-1, 0)),
        ("SPAN", (0, 2), (-1, 2)),
        ("BACKGROUND", (0, 0), (-1, -1), PALE),
        ("BOX", (0, 0), (-1, -1), 0.55, LINE_C),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, 0), 10),
        ("RIGHTPADDING", (0, 0), (-1, 0), 10),
        ("LEFTPADDING", (0, 2), (-1, 2), 10),
        ("RIGHTPADDING", (0, 2), (-1, 2), 10),
        ("LEFTPADDING", (0, 1), (-1, 1), 0),
        ("RIGHTPADDING", (0, 1), (-1, 1), 0),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]
    outer.setStyle(TableStyle(style_commands))
    return KeepTogether([Spacer(1, 4), outer, Spacer(1, 10)])


def interface_map():
    sidebar_title = ParagraphStyle(
        "InterfaceTableSidebarTitle",
        fontName=FONT_BOLD,
        fontSize=7.7,
        leading=9,
        textColor=TEAL,
        alignment=TA_CENTER,
    )
    sidebar_item = ParagraphStyle(
        "InterfaceTableSidebarItem",
        fontName=FONT,
        fontSize=6.3,
        leading=7.3,
        textColor=WHITE,
        alignment=TA_CENTER,
    )
    sidebar_rows = [[Paragraph("LEFT SIDEBAR", sidebar_title)]]
    for item in (
        "Home",
        "Multi-Gene Search",
        "Cross-Species Search",
        "Figure Studio",
        "CGeV Guide",
        "Settings / Feedback",
    ):
        sidebar_rows.append([Paragraph(item, sidebar_item)])
    sidebar = Table(sidebar_rows, colWidths=[112], rowHeights=[30] + [27] * 6)
    sidebar_commands = [
        ("BACKGROUND", (0, 0), (-1, -1), NAVY),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
        ("TOPPADDING", (0, 0), (-1, -1), 2),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 2),
    ]
    for row in range(1, 7):
        sidebar_commands.extend([
            ("BACKGROUND", (0, row), (0, row), NAVY_2),
            ("BOX", (0, row), (0, row), 0.4, HexColor("#425970")),
        ])
    sidebar.setStyle(TableStyle(sidebar_commands))

    main_title_style = ParagraphStyle(
        "InterfaceTableMainTitle",
        fontName=FONT_BOLD,
        fontSize=8,
        leading=9.5,
        textColor=NAVY,
        alignment=TA_LEFT,
    )
    section_title_base = ParagraphStyle(
        "InterfaceTableSectionTitle",
        fontName=FONT_BOLD,
        fontSize=7.15,
        leading=8.5,
        alignment=TA_LEFT,
    )
    section_detail = ParagraphStyle(
        "InterfaceTableSectionDetail",
        fontName=FONT,
        fontSize=6.4,
        leading=7.6,
        textColor=MUTED,
        alignment=TA_LEFT,
    )

    def section(accent, title, detail):
        title_style = section_title_base.clone(f"{title}TableStyle")
        title_style.textColor = accent
        content = Table(
            [[Paragraph(title, title_style)], [Paragraph(detail, section_detail)]],
            colWidths=[CONTENT_W - 160],
            rowHeights=[17, 22],
        )
        content.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, -1), WHITE),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ("LEFTPADDING", (0, 0), (-1, -1), 8),
            ("RIGHTPADDING", (0, 0), (-1, -1), 8),
            ("TOPPADDING", (0, 0), (-1, -1), 1),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 1),
        ]))
        block = Table([["", content]], colWidths=[8, CONTENT_W - 160], rowHeights=[39])
        block.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (0, 0), accent),
            ("BACKGROUND", (1, 0), (1, 0), WHITE),
            ("BOX", (0, 0), (-1, -1), 0.45, LINE_C),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ("LEFTPADDING", (0, 0), (-1, -1), 0),
            ("RIGHTPADDING", (0, 0), (-1, -1), 0),
            ("TOPPADDING", (0, 0), (-1, -1), 0),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 0),
        ]))
        return block

    main = Table(
        [
            [Paragraph("MAIN WORKSPACE", main_title_style)],
            [section(TEAL_DARK, "CONTEXT HEADER", "Workflow, organisms, current query, notifications, and display modes.")],
            [section(BLUE, "RESULT TOOLBAR", "Summary, CSV, analytics, batch SVG, sorting, and zoom.")],
            [section(NAVY_2, "INTERACTIVE RESULT CARDS", "Card header, gene model, transcript statistics, and analysis actions.")],
            [section(HexColor("#536A7E"), "ANALYSIS AND EXPORT", "Analytics, alignment views, Figure Studio, and sessions.")],
        ],
        colWidths=[CONTENT_W - 140],
        rowHeights=[27, 41, 41, 41, 41],
    )
    main.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), HexColor("#EEF3F5")),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 4),
        ("RIGHTPADDING", (0, 0), (-1, -1), 4),
        ("TOPPADDING", (0, 0), (-1, -1), 2),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 2),
    ]))
    outer = Table(
        [[sidebar, main]],
        colWidths=[122, CONTENT_W - 122],
        hAlign="CENTER",
    )
    outer.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), HexColor("#EEF3F5")),
        ("BOX", (0, 0), (-1, -1), 0.55, LINE_C),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (0, 0), 5),
        ("RIGHTPADDING", (0, 0), (0, 0), 5),
        ("LEFTPADDING", (1, 0), (1, 0), 5),
        ("RIGHTPADDING", (1, 0), (1, 0), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ]))
    return KeepTogether([Spacer(1, 4), outer, Spacer(1, 10)])


def screenshot_figure(filename: str, caption: str, max_height: float = 290):
    path = SCREENSHOT_DIR / filename
    if not path.exists():
        return build_callout(f"NOTE: Screenshot asset unavailable: {filename}")
    image = Image(str(path))
    ratio = image.imageHeight / image.imageWidth
    width = CONTENT_W
    height = width * ratio
    if height > max_height:
        height = max_height
        width = height / ratio
    image.drawWidth = width
    image.drawHeight = height
    image.hAlign = "CENTER"
    frame = Table([[image]], colWidths=[width + 8], hAlign="CENTER")
    frame.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), WHITE),
        ("BOX", (0, 0), (-1, -1), 0.55, LINE_C),
        ("LEFTPADDING", (0, 0), (-1, -1), 4),
        ("RIGHTPADDING", (0, 0), (-1, -1), 4),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]))
    return KeepTogether([
        Spacer(1, 5),
        frame,
            Paragraph(caption, STYLES["Caption"]),
        Spacer(1, 9),
    ])


def screenshot_interface():
    return screenshot_figure(
        "cgev_interface_orientation.png",
        "<b>Figure 2.1.</b> The real CGeV workspace with the Multi-Gene configuration panel open. "
        "The sidebar contains workflow navigation and gene entry; the main header controls visualization mode and detail.",
        max_height=274,
    )


def screenshot_cross_species():
    return screenshot_figure(
        "cgev_cross_species_workflow.png",
        "<b>Figure 5.1.</b> Cross-Species Gene Search before execution. "
        "The source selector includes Preloaded organisms, NCBI Search, Upload files, and Mixed sources.",
        max_height=274,
    )


def screenshot_result_card():
    return screenshot_figure(
        "cgv_result_card.png",
        "<b>Figure 6.1.</b> A real Compact result card for TP53I3 in <i>Homo sapiens</i>. "
        "The toolbar, database actions, structural model, transcript count, lengths, and sequence composition are visible.",
        max_height=255,
    )


def screenshot_analytics():
    return screenshot_figure(
        "cgv_analytics.png",
        "<b>Figure 8.1.</b> The analytics workspace with the ten chart families visible and Gene Architecture selected.",
        max_height=300,
    )


def screenshot_figure_studio():
    return screenshot_figure(
        "cgev_figure_studio.png",
        "<b>Figure 10.1.</b> Figure Studio publication controls, panel library, empty canvas, and selected-panel inspector.",
        max_height=310,
    )


def screenshot_settings():
    return screenshot_figure(
        "cgev_settings_workspace.png",
        "<b>Figure 12.1.</b> Settings provides appearance, interface, alias-source, organism, and work-session controls.",
        max_height=274,
    )


def export_matrix():
    rows = [
        ["Need", "Best export", "Why"],
        ["Edit a scientific figure", "SVG", "Vector structure, editable labels, scalable geometry"],
        ["Share a fixed raster preview", "PNG", "Predictable appearance and convenient placement"],
        ["Audit exact comparison values", "CSV", "Tabular data for statistics and record keeping"],
        ["Continue sequence analysis", "FASTA", "Gene, transcript, CDS, intron, promoter, or alignment sequences"],
        ["Resume the complete workspace", "RDS", "Sources, cards, views, settings, and Figure Studio state"],
    ]
    return build_table(rows, widths=[42 * mm, 39 * mm, CONTENT_W - 81 * mm])


def supported_organisms():
    rows = [["Organism", "TaxID", "Kingdom", "Reference assembly"]]
    with REGISTRY.open(newline="", encoding="utf-8") as handle:
        for record in csv.DictReader(handle, delimiter="\t"):
            annotation = Path(record["annotation"]).name
            match = re.search(r"(GC[AF]_\d+\.\d+)", annotation)
            if match:
                assembly = match.group(1)
            else:
                assembly_match = re.search(r"(ASM\d+v\d+)", annotation, flags=re.IGNORECASE)
                assembly = assembly_match.group(1) if assembly_match else annotation.replace("_genomic.gff.gz", "")
            rows.append([
                f"*{record['label']}*",
                record["taxid"],
                record["kingdom"],
                assembly,
            ])
    return build_table(
        rows,
        widths=[72 * mm, 24 * mm, 29 * mm, CONTENT_W - 125 * mm],
        compact=True,
    )


SPECIALS = {
    "[[WORKFLOW_DIAGRAM]]": workflow_diagram,
    "[[INTERFACE_MAP]]": interface_map,
    "[[SCREENSHOT_INTERFACE]]": screenshot_interface,
    "[[SCREENSHOT_CROSS_SPECIES]]": screenshot_cross_species,
    "[[SCREENSHOT_RESULT_CARD]]": screenshot_result_card,
    "[[SCREENSHOT_ANALYTICS]]": screenshot_analytics,
    "[[SCREENSHOT_FIGURE_STUDIO]]": screenshot_figure_studio,
    "[[SCREENSHOT_SETTINGS]]": screenshot_settings,
    "[[EXPORT_MATRIX]]": export_matrix,
    "[[SUPPORTED_ORGANISMS]]": supported_organisms,
}


def parse_table(lines: Sequence[str], start: int):
    raw = []
    i = start
    while i < len(lines) and lines[i].strip().startswith("|"):
        raw.append(lines[i].strip())
        i += 1
    rows = []
    for line in raw:
        cells = [cell.strip() for cell in line.strip("|").split("|")]
        if cells and all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells):
            continue
        rows.append(cells)
    return rows, i


def source_body() -> str:
    text = SOURCE.read_text(encoding="utf-8")
    replacements = {
        "{{MANUAL_VERSION}}": MANUAL_VERSION,
        "{{PRODUCT_VERSION}}": PRODUCT_VERSION,
        "{{REVISION_DISPLAY}}": REVISION_DISPLAY,
    }
    for token, value in replacements.items():
        text = text.replace(token, value)
    blocks = text.split("---PAGE---", 1)
    if len(blocks) != 2:
        raise ValueError("Manual source must contain a cover block followed by ---PAGE---")
    return blocks[1].lstrip()


def build_story():
    story = [
        CoverMarker(),
        NextPageTemplate("content"),
        PageBreak(),
        Paragraph("Contents", STYLES["TOCTitle"]),
        HRFlowable(width="100%", thickness=1.3, color=TEAL, spaceBefore=0, spaceAfter=12),
    ]

    toc = TableOfContents()
    toc.levelStyles = [STYLES["TOC0"], STYLES["TOC1"]]
    toc.dotsMinLevel = 0
    story.extend([toc, PageBreak()])

    lines = source_body().splitlines()
    i = 0
    paragraph_buffer: List[str] = []
    first_body_paragraph = True

    def flush_paragraph():
        nonlocal first_body_paragraph
        if not paragraph_buffer:
            return
        text = " ".join(part.strip() for part in paragraph_buffer)
        paragraph_buffer.clear()
        style = STYLES["Lead"] if first_body_paragraph else STYLES["Body"]
        story.append(Paragraph(inline_markup(text), style))
        first_body_paragraph = False

    while i < len(lines):
        line = lines[i].strip()
        if not line:
            flush_paragraph()
            i += 1
            continue
        if line == "---PAGE---":
            flush_paragraph()
            story.append(CondPageBreak(55 * mm))
            i += 1
            continue
        if line == "---HARDPAGE---":
            flush_paragraph()
            story.append(PageBreak())
            i += 1
            continue
        if line in SPECIALS:
            flush_paragraph()
            story.append(SPECIALS[line]())
            i += 1
            continue
        if line.startswith("|"):
            flush_paragraph()
            rows, i = parse_table(lines, i)
            story.append(build_table(rows))
            continue
        if line.startswith(">"):
            flush_paragraph()
            story.append(build_callout(line[1:].strip()))
            i += 1
            continue
        heading = re.match(r"^(#{1,3})\s+(.*)$", line)
        if heading:
            flush_paragraph()
            level = len(heading.group(1))
            story.append(Paragraph(inline_markup(heading.group(2)), STYLES[f"Heading{level}"]))
            if level == 1:
                rule = HRFlowable(
                    width="100%",
                    thickness=1.15,
                    color=TEAL,
                    spaceBefore=0,
                    spaceAfter=11,
                )
                rule.keepWithNext = True
                story.append(rule)
            i += 1
            continue
        bullet = re.match(r"^-\s+(.*)$", line)
        if bullet:
            flush_paragraph()
            story.append(Paragraph(
                inline_markup(bullet.group(1)),
                STYLES["Bullet"],
                bulletText="•",
            ))
            i += 1
            continue
        numbered = re.match(r"^(\d+)\.\s+(.*)$", line)
        if numbered:
            flush_paragraph()
            story.append(Paragraph(
                inline_markup(numbered.group(2)),
                STYLES["Number"],
                bulletText=f"{numbered.group(1)}.",
            ))
            i += 1
            continue
        paragraph_buffer.append(line)
        i += 1

    flush_paragraph()
    return story


def build_pdf(output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    doc = ManualDocTemplate(
        str(output),
        pagesize=A4,
        leftMargin=LEFT,
        rightMargin=RIGHT,
        topMargin=TOP,
        bottomMargin=BOTTOM,
        title="CGeV User Manual - Web and Desktop Edition",
        author="Comparative Gene Viewer",
        subject="Complete user manual for CGeV Web and CGeV Desktop",
        creator="Comparative Gene Viewer documentation",
        keywords="CGeV, comparative genomics, gene visualization, user manual, desktop",
    )
    cover_frame = Frame(0, 0, PAGE_W, PAGE_H, leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0)
    content_frame = Frame(
        LEFT,
        BOTTOM,
        CONTENT_W,
        PAGE_H - TOP - BOTTOM,
        leftPadding=0,
        rightPadding=0,
        topPadding=0,
        bottomPadding=0,
    )
    doc.addPageTemplates([
        PageTemplate(id="cover", frames=[cover_frame], onPage=draw_cover),
        PageTemplate(id="content", frames=[content_frame], onPage=draw_content_page),
    ])
    doc.multiBuild(build_story(), maxPasses=4)


def publish_manual(source_pdf: Path) -> None:
    PUBLIC_LATEST.parent.mkdir(parents=True, exist_ok=True)
    PUBLIC_ARCHIVE.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source_pdf, PUBLIC_LATEST)
    # Keep the former stable URL serving the current manual so existing Web and
    # Desktop installations do not lose their documentation link.
    shutil.copy2(source_pdf, LEGACY_PUBLIC_LATEST)
    shutil.copy2(source_pdf, PUBLIC_ARCHIVE)
    metadata = {
        "title": str(CONFIG["title"]),
        "edition": str(CONFIG["edition"]),
        "language": str(CONFIG["language"]),
        "manual_version": MANUAL_VERSION,
        "product_version": PRODUCT_VERSION,
        "revision_date": REVISION_DATE,
        "revision_display": REVISION_DISPLAY,
        "latest_url": f"docs/{PUBLIC_FILENAME}",
        "legacy_url": "docs/CGV_User_Manual.pdf",
        "archive_url": f"docs/archive/{VERSIONED_FILENAME}",
    }
    PUBLIC_METADATA.write_text(
        json.dumps(metadata, indent=2, ensure_ascii=True) + "\n",
        encoding="utf-8",
    )


def main(argv: Sequence[str]) -> int:
    target = Path(argv[1]).resolve() if len(argv) > 1 else OUTPUT
    build_pdf(target)
    if len(argv) == 1:
        publish_manual(target)
    print(target)
    if len(argv) == 1:
        print(PUBLIC_LATEST)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
