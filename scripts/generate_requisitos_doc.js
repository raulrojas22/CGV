const fs = require("fs");
const path = require("path");
const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  Header, Footer, AlignmentType, HeadingLevel, BorderStyle, WidthType,
  ShadingType, PageNumber, PageBreak, TableOfContents, LevelFormat,
} = require("docx");

// ── Colors ──
const BLUE_DARK = "1B3A5C";
const BLUE_MED = "2E75B6";
const BLUE_LIGHT = "D5E8F0";
const GRAY_LIGHT = "F2F2F2";
const GRAY_MED = "E6E6E6";
const WHITE = "FFFFFF";

// ── Helpers ──
const border = { style: BorderStyle.SINGLE, size: 1, color: "CCCCCC" };
const borders = { top: border, bottom: border, left: border, right: border };
const cellMargins = { top: 60, bottom: 60, left: 100, right: 100 };

const PAGE_WIDTH = 12240;
const MARGIN = 1440;
const CONTENT_WIDTH = PAGE_WIDTH - 2 * MARGIN; // 9360

function headerCell(text, width) {
  return new TableCell({
    borders,
    width: { size: width, type: WidthType.DXA },
    shading: { fill: BLUE_DARK, type: ShadingType.CLEAR },
    margins: cellMargins,
    verticalAlign: "center",
    children: [new Paragraph({
      alignment: AlignmentType.CENTER,
      children: [new TextRun({ text, bold: true, color: WHITE, font: "Arial", size: 20 })],
    })],
  });
}

function dataCell(text, width, opts = {}) {
  const { bold, shade, align, size: sz } = { bold: false, shade: null, align: AlignmentType.LEFT, size: 20, ...opts };
  return new TableCell({
    borders,
    width: { size: width, type: WidthType.DXA },
    shading: shade ? { fill: shade, type: ShadingType.CLEAR } : undefined,
    margins: cellMargins,
    children: [new Paragraph({
      alignment: align,
      children: [new TextRun({ text, bold, font: "Arial", size: sz })],
    })],
  });
}

function makeTable(headers, rows, colWidths) {
  const tableWidth = colWidths.reduce((a, b) => a + b, 0);
  return new Table({
    width: { size: tableWidth, type: WidthType.DXA },
    columnWidths: colWidths,
    rows: [
      new TableRow({ children: headers.map((h, i) => headerCell(h, colWidths[i])) }),
      ...rows.map((row, ri) =>
        new TableRow({
          children: row.map((cell, ci) =>
            dataCell(cell, colWidths[ci], {
              shade: ri % 2 === 1 ? GRAY_LIGHT : WHITE,
              bold: cell === "TOTAL",
              align: ci > 0 ? AlignmentType.CENTER : AlignmentType.LEFT,
            })
          ),
        })
      ),
    ],
  });
}

function heading1(text) {
  return new Paragraph({ heading: HeadingLevel.HEADING_1, spacing: { before: 360, after: 200 }, children: [new TextRun({ text })] });
}
function heading2(text) {
  return new Paragraph({ heading: HeadingLevel.HEADING_2, spacing: { before: 240, after: 160 }, children: [new TextRun({ text })] });
}
function para(text, opts = {}) {
  const { bold, spacing, size: sz } = { bold: false, spacing: { after: 120 }, size: 22, ...opts };
  return new Paragraph({ spacing, children: [new TextRun({ text, bold, font: "Arial", size: sz })] });
}
function bulletItem(text, ref) {
  return new Paragraph({
    numbering: { reference: ref, level: 0 },
    spacing: { after: 60 },
    children: [new TextRun({ text, font: "Arial", size: 22 })],
  });
}

// ── Document ──
const doc = new Document({
  styles: {
    default: { document: { run: { font: "Arial", size: 22 } } },
    paragraphStyles: [
      {
        id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 32, bold: true, color: BLUE_DARK, font: "Arial" },
        paragraph: { spacing: { before: 360, after: 200 }, outlineLevel: 0 },
      },
      {
        id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 26, bold: true, color: BLUE_MED, font: "Arial" },
        paragraph: { spacing: { before: 240, after: 160 }, outlineLevel: 1 },
      },
    ],
  },
  numbering: {
    config: [
      {
        reference: "bullets",
        levels: [{
          level: 0, format: LevelFormat.BULLET, text: "\u2022", alignment: AlignmentType.LEFT,
          style: { paragraph: { indent: { left: 720, hanging: 360 } } },
        }],
      },
    ],
  },
  sections: [
    // ══════ COVER PAGE ══════
    {
      properties: {
        page: {
          size: { width: PAGE_WIDTH, height: 15840 },
          margin: { top: MARGIN, right: MARGIN, bottom: MARGIN, left: MARGIN },
        },
      },
      children: [
        new Paragraph({ spacing: { before: 3000 } }),
        new Paragraph({
          alignment: AlignmentType.CENTER,
          spacing: { after: 200 },
          children: [new TextRun({ text: "REQUISITOS DE INFRAESTRUCTURA", bold: true, font: "Arial", size: 48, color: BLUE_DARK })],
        }),
        new Paragraph({
          alignment: AlignmentType.CENTER,
          spacing: { after: 100 },
          children: [new TextRun({ text: "CGV", bold: true, font: "Arial", size: 72, color: BLUE_MED })],
        }),
        new Paragraph({
          alignment: AlignmentType.CENTER,
          spacing: { after: 400 },
          children: [new TextRun({ text: "Comparative Genomics Viewer", font: "Arial", size: 28, color: BLUE_MED, italics: true })],
        }),
        new Paragraph({
          alignment: AlignmentType.CENTER,
          border: { top: { style: BorderStyle.SINGLE, size: 6, color: BLUE_MED, space: 1 } },
          spacing: { before: 600, after: 200 },
          children: [new TextRun({ text: "Especificaciones t\u00E9cnicas para despliegue en servidor Linux", font: "Arial", size: 24, color: "555555" })],
        }),
        new Paragraph({ spacing: { before: 1200 } }),
        new Paragraph({
          alignment: AlignmentType.CENTER,
          spacing: { after: 80 },
          children: [new TextRun({ text: "Autor: Raul Rojas", font: "Arial", size: 22 })],
        }),
        new Paragraph({
          alignment: AlignmentType.CENTER,
          spacing: { after: 80 },
          children: [new TextRun({ text: "Fecha: 22 de marzo de 2026", font: "Arial", size: 22 })],
        }),
        new Paragraph({
          alignment: AlignmentType.CENTER,
          spacing: { after: 80 },
          children: [new TextRun({ text: "Versi\u00F3n de la aplicaci\u00F3n: CGV 1.0.0", font: "Arial", size: 22 })],
        }),
        new Paragraph({
          alignment: AlignmentType.CENTER,
          spacing: { before: 200 },
          children: [new TextRun({ text: "DOCUMENTO CONFIDENCIAL", bold: true, font: "Arial", size: 18, color: "999999" })],
        }),
      ],
    },
    // ══════ TOC + CONTENT ══════
    {
      properties: {
        page: {
          size: { width: PAGE_WIDTH, height: 15840 },
          margin: { top: MARGIN, right: MARGIN, bottom: MARGIN, left: MARGIN },
        },
      },
      headers: {
        default: new Header({
          children: [new Paragraph({
            border: { bottom: { style: BorderStyle.SINGLE, size: 4, color: BLUE_MED, space: 4 } },
            spacing: { after: 200 },
            children: [
              new TextRun({ text: "CGV \u2014 Requisitos de Infraestructura", font: "Arial", size: 18, color: "999999", italics: true }),
            ],
          })],
        }),
      },
      footers: {
        default: new Footer({
          children: [new Paragraph({
            alignment: AlignmentType.CENTER,
            border: { top: { style: BorderStyle.SINGLE, size: 4, color: GRAY_MED, space: 4 } },
            children: [
              new TextRun({ text: "P\u00E1gina ", font: "Arial", size: 18, color: "999999" }),
              new TextRun({ children: [PageNumber.CURRENT], font: "Arial", size: 18, color: "999999" }),
            ],
          })],
        }),
      },
      children: [
        // TOC
        new Paragraph({
          heading: HeadingLevel.HEADING_1,
          spacing: { after: 300 },
          children: [new TextRun({ text: "\u00CDndice" })],
        }),
        new TableOfContents("Tabla de Contenidos", { hyperlink: true, headingStyleRange: "1-2" }),
        new Paragraph({ children: [new PageBreak()] }),

        // ── 1. INTRODUCCIÓN ──
        heading1("1. Introducci\u00F3n"),
        para("CGV (Comparative Genomics Viewer) es una aplicaci\u00F3n web interactiva desarrollada en R/Shiny para an\u00E1lisis de gen\u00F3mica comparativa. Permite b\u00FAsqueda de genes, an\u00E1lisis de ort\u00F3logos, alineamiento de secuencias, enriquecimiento GO y visualizaci\u00F3n de redes de interacci\u00F3n prote\u00EDca."),
        para("La aplicaci\u00F3n se despliega como contenedor Docker y requiere acceso a datasets biol\u00F3gicos de referencia. Este documento detalla los requisitos m\u00EDnimos y recomendados de hardware, almacenamiento y red para un despliegue exitoso en entorno de producci\u00F3n."),

        // ── 2. INVENTARIO DE DATOS ──
        heading1("2. Inventario de datos"),
        para("La siguiente tabla detalla el desglose de almacenamiento actual y la proyecci\u00F3n estimada considerando la incorporaci\u00F3n de nuevos organismos:"),
        makeTable(
          ["Componente", "Tama\u00F1o actual", "Proyecci\u00F3n"],
          [
            ["Imagen Docker (SO + R + dependencias)", "2.5 GB", "3 GB"],
            ["Anotaciones gen\u00F3micas (52 organismos)", "616 MB", "1 GB"],
            ["Genomas en formato .2bit (28 genomas)", "12 GB", "20 GB"],
            ["Anotaciones GO", "122 MB", "200 MB"],
            ["Cach\u00E9 de \u00EDndices precomputados", "1 GB", "2 GB"],
            ["Sistema operativo Linux + Docker Engine", "\u2014", "15 GB"],
            ["TOTAL", "~16 GB", "~40 GB"],
          ],
          [5000, 2180, 2180]
        ),
        para(""),
        para("Nota: El genoma humano (GRCh38) ocupa 916 MB; Brachypodium distachyon reduce sustancialmente el paquete vegetal de referencia.", { bold: false, size: 20 }),

        // ── 3. REQUISITOS DE RAM ──
        new Paragraph({ children: [new PageBreak()] }),
        heading1("3. Requisitos de memoria RAM"),
        heading2("3.1 Consumo por escenario"),
        para("Valores medidos en contenedor Docker con la configuraci\u00F3n actual de 25 organismos indexados:"),
        makeTable(
          ["Escenario", "RAM estimada"],
          [
            ["Aplicaci\u00F3n en reposo (1 usuario, sin operaciones activas)", "~260 MB"],
            ["Pre-warm al arrancar (indexaci\u00F3n de 25 organismos)", "1.5 \u2013 2 GB (pico)"],
            ["1 usuario activo realizando b\u00FAsquedas y alineamientos", "500 MB \u2013 1 GB"],
            ["An\u00E1lisis de ort\u00F3logos con genomas grandes (trigo, humano)", "1.5 \u2013 2.5 GB (pico)"],
            ["Enriquecimiento GO + visualizaci\u00F3n de redes", "300 \u2013 500 MB adicional"],
            ["Multi-usuario (5 sesiones concurrentes)", "3 \u2013 5 GB"],
          ],
          [6500, 2860]
        ),
        para(""),
        heading2("3.2 Recomendaci\u00F3n"),
        makeTable(
          ["Perfil de uso", "RAM a solicitar"],
          [
            ["M\u00EDnimo funcional (1-2 usuarios)", "4 GB"],
            ["Recomendado (3-5 usuarios)", "8 GB"],
            ["C\u00F3modo (5-10 usuarios, margen para picos)", "16 GB"],
          ],
          [6500, 2860]
        ),

        // ── 4. REQUISITOS DE CPU ──
        new Paragraph({ children: [new PageBreak()] }),
        heading1("4. Requisitos de CPU"),
        heading2("4.1 Demanda por operaci\u00F3n"),
        makeTable(
          ["Operaci\u00F3n", "Demanda de CPU"],
          [
            ["Navegaci\u00F3n de la interfaz (idle)", "M\u00EDnima (~0.1%)"],
            ["B\u00FAsqueda de genes (autocomplete)", "Baja (1 core, <1 segundo)"],
            ["Alineamiento por k-mer (modo r\u00E1pido)", "Media (1 core, 2-5 segundos)"],
            ["Alineamiento completo (Biostrings)", "Alta (1 core, 10-30 segundos)"],
            ["Pre-warm al arrancar", "Media (1 core, 8-10 minutos)"],
            ["Build de imagen Docker (solo una vez)", "Alta (todos los cores, 15-20 min)"],
          ],
          [5000, 4360]
        ),
        para(""),
        heading2("4.2 Recomendaci\u00F3n"),
        makeTable(
          ["Perfil de uso", "CPUs a solicitar"],
          [
            ["M\u00EDnimo funcional", "2 vCPU / cores"],
            ["Recomendado", "4 vCPU / cores"],
            ["Multi-usuario c\u00F3modo", "4-8 vCPU / cores"],
          ],
          [5000, 4360]
        ),

        // ── 5. RESUMEN ──
        new Paragraph({ children: [new PageBreak()] }),
        heading1("5. Resumen de especificaciones"),
        para("Tabla consolidada de requisitos para solicitud de recursos:"),
        makeTable(
          ["Recurso", "M\u00EDnimo", "Recomendado"],
          [
            ["CPU", "2 vCPU", "4 vCPU"],
            ["RAM", "4 GB", "8 GB (16 GB ideal)"],
            ["Almacenamiento", "50 GB", "100 GB SSD"],
            ["Sistema operativo", "Ubuntu 22.04 LTS+", "Ubuntu 24.04 LTS"],
            ["Docker", "v24+", "v27+ con Compose v2"],
            ["Red", "Acceso saliente a internet", "NCBI, UniProt, MyGene"],
            ["Puerto", "3838 (configurable)", "3838 (configurable)"],
          ],
          [3120, 3120, 3120]
        ),

        // ── 6. CONSIDERACIONES ADICIONALES ──
        new Paragraph({ children: [new PageBreak()] }),
        heading1("6. Consideraciones adicionales"),

        heading2("6.1 Almacenamiento"),
        bulletItem("Se recomienda SSD sobre HDD. Los genomas en formato .2bit se leen con acceso aleatorio; un SSD reduce la latencia de alineamientos de ~30 segundos a ~5 segundos.", "bullets"),
        bulletItem("Configurar 2-4 GB de swap como respaldo ante picos de consumo de memoria en an\u00E1lisis de genomas grandes.", "bullets"),

        heading2("6.2 Red y seguridad"),
        bulletItem("La aplicaci\u00F3n requiere acceso saliente a internet para consultar APIs externas: NCBI E-utilities, UniProt, MyGene.info.", "bullets"),
        bulletItem("Solo es necesario abrir el puerto 3838 (o el que se configure) para acceso entrante.", "bullets"),
        bulletItem("Los secretos (API keys) se gestionan mediante archivos .env.local que nunca se incluyen en la imagen Docker.", "bullets"),

        heading2("6.3 Backups"),
        bulletItem("Solo los directorios de datos requieren respaldo: annotations/, genomes/, go_annotations/.", "bullets"),
        bulletItem("El cach\u00E9 (cache/) se regenera autom\u00E1ticamente con el pre-warm al arrancar el contenedor.", "bullets"),
        bulletItem("La imagen Docker se reconstruye a partir del c\u00F3digo fuente.", "bullets"),

        heading2("6.4 Mantenimiento"),
        bulletItem("La aplicaci\u00F3n se reinicia autom\u00E1ticamente tras un reinicio del servidor (pol\u00EDtica restart: unless-stopped).", "bullets"),
        bulletItem("Para actualizar versiones: reconstruir la imagen Docker y recrear el contenedor. Los datos persisten en vol\u00FAmenes externos.", "bullets"),

        // ── 7. STACK TECNOLÓGICO ──
        heading1("7. Stack tecnol\u00F3gico"),
        makeTable(
          ["Categor\u00EDa", "Tecnolog\u00EDa"],
          [
            ["Lenguaje", "R 4.5"],
            ["Framework web", "Shiny + bslib"],
            ["Bioinform\u00E1tica", "Biostrings, GenomicRanges, Rsamtools, rtracklayer"],
            ["Visualizaci\u00F3n", "ggplot2, ggiraph, visNetwork, patchwork"],
            ["Contenedorizaci\u00F3n", "Docker (imagen base rocker/r-ver:4.5)"],
            ["Datos", "Archivos .2bit, tabulares de anotaci\u00F3n, cach\u00E9 en disco"],
          ],
          [3120, 6240]
        ),
      ],
    },
  ],
});

const OUTPUT = path.resolve(__dirname, "..", "CGV_Requisitos_Infraestructura.docx");
Packer.toBuffer(doc).then(buffer => {
  fs.writeFileSync(OUTPUT, buffer);
  console.log("Document created: " + OUTPUT);
});
