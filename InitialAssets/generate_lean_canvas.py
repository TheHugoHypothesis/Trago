#!/usr/bin/env python3
"""
Gerador do Lean Canvas oficial do projeto Trago! utilizando Matplotlib.
Exporta versões em alta resolução (PNG 300 DPI), PDF vetorial e SVG vetorial
seguindo a identidade visual de Design.png (Navy #001C44, Coral #FE5656, Mint #0E9F6E).
"""

from pathlib import Path
import textwrap
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
from matplotlib.patches import FancyBboxPatch, Circle

# Desabilita interpretação de '$' como modo matemático TeX (essencial para "US$" e "R$")
plt.rcParams["text.parse_math"] = False

# Paleta Oficial Trago! (extraída de InitialAssets/Design.png)
NAVY = "#001C44"
NAVY_LIGHT = "#0A2E63"
CORAL = "#FE5656"
CORAL_SOFT = "#FFF1F1"
MINT_BG = "#D7F2E4"
MINT_TEXT = "#0E9F6E"
SKY_BG = "#EAF5FE"
SKY_ACCENT = "#0284C7"
GOLD_BG = "#FEF3C7"
GOLD_ACCENT = "#D97706"
BG_CANVAS = "#F1F5F9"
CARD_BG = "#FFFFFF"
BORDER_COLOR = "#CBD5E1"
TEXT_DARK = "#0F172A"
TEXT_MUTED = "#475569"

FONT_DIR = Path("/usr/local/share/fonts/i")


def get_font(weight: str, size: float) -> FontProperties:
    """Carrega a família tipográfica Inter estática com fallback seguro."""
    mapping = {
        "regular": "Inter_18pt_Regular.ttf",
        "medium": "Inter_18pt_Medium.ttf",
        "semibold": "Inter_18pt_SemiBold.ttf",
        "bold": "Inter_18pt_Bold.ttf",
        "extrabold": "Inter_18pt_ExtraBold.ttf",
        "black": "Inter_18pt_Black.ttf",
    }
    ttf_path = FONT_DIR / mapping.get(weight, "Inter_18pt_Regular.ttf")
    if ttf_path.exists():
        return FontProperties(fname=str(ttf_path), size=size)
    return FontProperties(
        family="DejaVu Sans",
        weight="bold" if weight in ("bold", "extrabold", "black", "semibold") else "normal",
        size=size,
    )


def draw_card(
    ax,
    x: float,
    y: float,
    w: float,
    h: float,
    number: str,
    title: str,
    subtitle: str,
    bullets: list[tuple[str, str]],
    accent_color: str = NAVY,
    badge_bg: str = SKY_BG,
    footer_title: str | None = None,
    footer_items: list[str] | None = None,
    footer_ratio: float = 0.28,
    highlight_box: tuple[str, str] | None = None,
):
    """Desenha um bloco estilizado do Lean Canvas em coordenadas isotrópicas (0..160 x 0..100)."""
    # Sombra suave
    shadow = FancyBboxPatch(
        (x + 0.28, y - 0.32),
        w,
        h,
        boxstyle="round,pad=0,rounding_size=1.3",
        facecolor="#0F172A",
        alpha=0.06,
        edgecolor="none",
        zorder=1,
    )
    ax.add_patch(shadow)

    # Cartão principal
    card = FancyBboxPatch(
        (x, y),
        w,
        h,
        boxstyle="round,pad=0,rounding_size=1.3",
        facecolor=CARD_BG,
        edgecolor=BORDER_COLOR,
        linewidth=1.4,
        zorder=2,
    )
    ax.add_patch(card)

    # Barra superior de destaque (accent)
    top_strip = FancyBboxPatch(
        (x, y + h - 0.9),
        w,
        0.9,
        boxstyle="round,pad=0,rounding_size=0.45",
        facecolor=accent_color,
        edgecolor="none",
        zorder=3,
    )
    ax.add_patch(top_strip)

    # Círculo perfeitamente redondo numerado do bloco Lean Canvas
    badge_x = x + 2.2
    badge_y = y + h - 2.65
    badge_circle = Circle(
        (badge_x, badge_y),
        radius=1.18,
        facecolor=accent_color,
        edgecolor="none",
        zorder=4,
    )
    ax.add_patch(badge_circle)
    ax.text(
        badge_x,
        badge_y,
        number,
        color="#FFFFFF",
        fontproperties=get_font("extrabold", 10.5),
        ha="center",
        va="center",
        zorder=5,
    )

    # Título e subtítulo do bloco
    ax.text(
        x + 3.9,
        badge_y + 0.35,
        title.upper(),
        color=NAVY,
        fontproperties=get_font("extrabold", 10.5),
        ha="left",
        va="center",
        zorder=5,
    )
    ax.text(
        x + 3.9,
        badge_y - 0.65,
        subtitle,
        color=TEXT_MUTED,
        fontproperties=get_font("medium", 8.0),
        ha="left",
        va="center",
        zorder=5,
    )

    # Linha divisória do cabeçalho do card
    header_bottom = y + h - 4.25
    ax.plot(
        [x + 1.2, x + w - 1.2],
        [header_bottom, header_bottom],
        color="#E2E8F0",
        linewidth=1.1,
        zorder=3,
    )

    # Largura de quebra de texto proporcional à largura isotrópica w
    wrap_chars = int(w * 1.44)
    cursor_y = header_bottom - 1.05
    line_height = 1.12

    for bold_lead, body_text in bullets:
        # Ponto colorido (bullet)
        ax.plot(
            x + 1.65,
            cursor_y - 0.32,
            marker="o",
            markersize=4.8,
            color=accent_color,
            zorder=5,
        )

        # Título do tópico em negrito
        ax.text(
            x + 2.55,
            cursor_y,
            bold_lead,
            color=TEXT_DARK,
            fontproperties=get_font("bold", 8.7),
            ha="left",
            va="top",
            zorder=5,
        )
        cursor_y -= line_height * 1.04

        # Corpo do tópico com quebra automática
        wrapped_lines = textwrap.wrap(body_text, width=wrap_chars)
        for line in wrapped_lines:
            ax.text(
                x + 2.55,
                cursor_y,
                line,
                color=TEXT_MUTED,
                fontproperties=get_font("regular", 8.0),
                ha="left",
                va="top",
                zorder=5,
            )
            cursor_y -= line_height * 0.88

        cursor_y -= 0.55

    # Caixa de destaque opcional no meio (ex: Promessa Central na Proposta de Valor)
    if highlight_box is not None:
        hl_title, hl_text = highlight_box
        hl_lines = textwrap.wrap(hl_text, width=wrap_chars - 4)
        box_h = 2.1 + len(hl_lines) * (line_height * 0.88)
        box_y = cursor_y - box_h + 0.15
        hl_patch = FancyBboxPatch(
            (x + 1.15, box_y),
            w - 2.3,
            box_h,
            boxstyle="round,pad=0,rounding_size=0.85",
            facecolor=badge_bg,
            edgecolor=accent_color,
            linewidth=1.1,
            zorder=3,
        )
        ax.add_patch(hl_patch)
        ax.text(
            x + 1.95,
            box_y + box_h - 0.65,
            hl_title,
            color=accent_color,
            fontproperties=get_font("extrabold", 8.1),
            ha="left",
            va="top",
            zorder=5,
        )
        hl_cursor = box_y + box_h - 1.75
        for line in hl_lines:
            ax.text(
                x + 1.95,
                hl_cursor,
                line,
                color=NAVY,
                fontproperties=get_font("semibold", 7.8),
                ha="left",
                va="top",
                zorder=5,
            )
            hl_cursor -= line_height * 0.86

    # Sub-bloco inferior (Alternativas Existentes / Conceito de Alto Nível / Early Adopters)
    if footer_title and footer_items:
        footer_h = h * footer_ratio
        footer_y = y + 0.85
        footer_box = FancyBboxPatch(
            (x + 0.95, footer_y),
            w - 1.9,
            footer_h,
            boxstyle="round,pad=0,rounding_size=0.9",
            facecolor=badge_bg,
            edgecolor="none",
            zorder=3,
        )
        ax.add_patch(footer_box)

        ax.text(
            x + 1.85,
            footer_y + footer_h - 0.8,
            footer_title.upper(),
            color=NAVY,
            fontproperties=get_font("extrabold", 8.1),
            ha="left",
            va="top",
            zorder=5,
        )

        f_cursor = footer_y + footer_h - 2.0
        for item in footer_items:
            wrapped = textwrap.wrap(item, width=wrap_chars - 3)
            for idx, line in enumerate(wrapped):
                prefix = "• " if idx == 0 else "   "
                ax.text(
                    x + 1.85,
                    f_cursor,
                    prefix + line,
                    color=TEXT_DARK,
                    fontproperties=get_font("semibold" if idx == 0 else "regular", 7.8),
                    ha="left",
                    va="top",
                    zorder=5,
                )
                f_cursor -= line_height * 0.84
            f_cursor -= 0.22


def build_lean_canvas(output_dir: Path):
    # Figura widescreen 16:10 (22 x 13.75 pol) com coordenadas isotrópicas (160 x 100)
    fig, ax = plt.subplots(figsize=(22, 13.75), dpi=200)
    fig.patch.set_facecolor(BG_CANVAS)
    ax.set_facecolor(BG_CANVAS)
    ax.set_xlim(0, 160)
    ax.set_ylim(0, 100)
    ax.set_aspect("equal")
    ax.axis("off")

    # =========================================================================
    # CABEÇALHO SUPERIOR (BRANDING TRAGO! + METADADOS DO PROJETO)
    # =========================================================================
    header_bg = FancyBboxPatch(
        (2.2, 91.2),
        155.6,
        7.3,
        boxstyle="round,pad=0,rounding_size=1.4",
        facecolor=NAVY,
        edgecolor="none",
        zorder=2,
    )
    ax.add_patch(header_bg)

    # Selo Coral "TRAGO!"
    logo_pill = FancyBboxPatch(
        (4.0, 92.4),
        17.5,
        4.9,
        boxstyle="round,pad=0,rounding_size=1.0",
        facecolor=CORAL,
        edgecolor="none",
        zorder=3,
    )
    ax.add_patch(logo_pill)
    ax.text(
        12.75,
        94.85,
        "TRAGO!",
        color="#FFFFFF",
        fontproperties=get_font("black", 20.5),
        ha="center",
        va="center",
        zorder=4,
    )

    ax.text(
        23.8,
        95.75,
        "LEAN CANVAS — PLATAFORMA DE CROWD-SHIPPING & IMPORTAÇÃO DISTRIBUÍDA (PF & PJ)",
        color="#FFFFFF",
        fontproperties=get_font("extrabold", 14.2),
        ha="left",
        va="center",
        zorder=4,
    )
    ax.text(
        23.8,
        93.2,
        "A Nova Rota da Importação Global   •   Smart Matching de Viajantes   •   Motor Fiscal Automatizado   •   Custódia Segura (Escrow)",
        color="#CBD5E1",
        fontproperties=get_font("medium", 9.6),
        ha="left",
        va="center",
        zorder=4,
    )

    # Pílula de validação no canto direito do cabeçalho
    val_pill = FancyBboxPatch(
        (123.0, 92.45),
        33.0,
        4.8,
        boxstyle="round,pad=0,rounding_size=0.95",
        facecolor=NAVY_LIGHT,
        edgecolor="#334155",
        linewidth=1.1,
        zorder=3,
    )
    ax.add_patch(val_pill)
    ax.text(
        139.5,
        95.6,
        "VALIDAÇÃO DE MERCADO (N = 48)",
        color="#38BDF8",
        fontproperties=get_font("extrabold", 8.8),
        ha="center",
        va="center",
        zorder=4,
    )
    ax.text(
        139.5,
        93.6,
        "EACH-USP • BSI • Empreendedorismo em Informática",
        color="#E2E8F0",
        fontproperties=get_font("medium", 7.8),
        ha="center",
        va="center",
        zorder=4,
    )

    # =========================================================================
    # GEOMETRIA DA GRADE LEAN CANVAS (5 COLUNAS EM CIMA, 2 EMBAIXO)
    # =========================================================================
    margin_x = 2.2
    gap_x = 1.4
    total_w = 160.0 - 2 * margin_x
    col_w = (total_w - 4 * gap_x) / 5.0  # 30.0 por coluna

    top_row_y = 28.8
    top_row_h = 61.0
    half_gap_y = 1.2
    half_h = (top_row_h - half_gap_y) / 2.0  # 29.9 cada meio bloco

    bot_row_y = 3.2
    bot_row_h = 24.3
    bot_col_w = (total_w - gap_x) / 2.0  # 77.1 cada bloco inferior

    col_x = [margin_x + i * (col_w + gap_x) for i in range(5)]

    # -------------------------------------------------------------------------
    # BLOCO 1: PROBLEMA (Coluna 0, altura inteira)
    # -------------------------------------------------------------------------
    draw_card(
        ax,
        x=col_x[0],
        y=top_row_y,
        w=col_w,
        h=top_row_h,
        number="1",
        title="Problema",
        subtitle="Top 3 dores do mercado cross-border",
        accent_color=CORAL,
        badge_bg=CORAL_SOFT,
        bullets=[
            (
                "1. Fretes internacionais abusivos",
                "Transportadoras expressas e couriers frequentemente cobram tarifas logísticas que superam o preço do próprio produto.",
            ),
            (
                "2. Incerteza tributária e surpresas fiscais",
                "Complexidade das alíquotas de importação gera receio de multas ou retenções inesperadas na Receita Federal (apontado por 100% dos idosos e PMEs entrevistados).",
            ),
            (
                "3. Prazos longos e burocracia B2B/B2C",
                "Encomendas retidas em centros alfandegários tradicionais atrasam entregas de consumidores PF e paralisam projetos de PMEs que dependem de protótipos e peças.",
            ),
        ],
        footer_title="Alternativas Existentes",
        footer_items=[
            "Plataformas C2C informais (Grabr) sem suporte fiscal PJ.",
            "Redirecionadores postais nos EUA (UsCloser, Zip4Me).",
            "Couriers expressos tradicionais (DHL, FedEx, UPS).",
            "Importação direta via varejistas (Remessa Conforme).",
        ],
        footer_ratio=0.28,
    )

    # -------------------------------------------------------------------------
    # BLOCO 4: SOLUÇÃO (Coluna 1, metade superior)
    # -------------------------------------------------------------------------
    draw_card(
        ax,
        x=col_x[1],
        y=top_row_y + half_h + half_gap_y,
        w=col_w,
        h=half_h,
        number="4",
        title="Solução",
        subtitle="Os 3 pilares tecnológicos do Trago!",
        accent_color=NAVY,
        badge_bg=SKY_BG,
        bullets=[
            (
                "Smart Matching de Rotas Aéreas",
                "Conexão determinística entre pedidos e viajantes verificados com franquia ociosa (JFK, MIA, LHR, HND, CDG → GRU/GIG/CWB).",
            ),
            (
                "Motor de Automação Fiscal PF & PJ",
                "Cálculo antecipado de tributos, câmbio comercial ao vivo (USD/EUR/GBP) e emissão de documentação contábil para CNPJ.",
            ),
            (
                "Custódia Segura (Escrow via PIX)",
                "Valor pago fica retido e só é liberado ao viajante após a entrega física confirmada e validada pelo comprador.",
            ),
        ],
    )

    # -------------------------------------------------------------------------
    # BLOCO 8: MÉTRICAS-CHAVE (Coluna 1, metade inferior)
    # -------------------------------------------------------------------------
    draw_card(
        ax,
        x=col_x[1],
        y=top_row_y,
        w=col_w,
        h=half_h,
        number="8",
        title="Métricas-Chave",
        subtitle="Indicadores de tração e liquidez",
        accent_color=SKY_ACCENT,
        badge_bg=SKY_BG,
        bullets=[
            (
                "GMV & Ticket Médio (> US$ 100)",
                "Volume bruto transacionado por corredor aéreo e economia percentual gerada frente ao varejo local.",
            ),
            (
                "Conversão do Funil de 4 Etapas",
                "Taxa de avanço: Pedido → Cálculo Fiscal → Pagamento em Custódia → Acompanhamento/Entrega.",
            ),
            (
                "Liquidez da Malha de Viajantes",
                "Quilogramas ofertados vs. reservados por rota, tempo até matching e taxa de entregas sem disputa (> 98%).",
            ),
        ],
    )

    # -------------------------------------------------------------------------
    # BLOCO 3: PROPOSTA DE VALOR ÚNICA (Coluna 2, altura inteira)
    # -------------------------------------------------------------------------
    draw_card(
        ax,
        x=col_x[2],
        y=top_row_y,
        w=col_w,
        h=top_row_h,
        number="3",
        title="Proposta de Valor",
        subtitle="Por que o Trago! merece atenção",
        accent_color=MINT_TEXT,
        badge_bg=MINT_BG,
        bullets=[
            (
                "Para Compradores PF (B2C)",
                "Compre produtos internacionais e receba em mãos com viajantes reais, economizando até 60% com cálculo fiscal transparente antes de pagar.",
            ),
            (
                "Para Empresas & PMEs (B2B)",
                "Importação ágil de insumos, placas, sensores e protótipos com segregação de conta CNPJ e relatórios compatíveis com a contabilidade.",
            ),
            (
                "Para Viajantes Internacionais",
                "Monetize cada quilo livre da sua bagagem (US$ 40 a US$ 48/kg) para abater custos da passagem com segurança jurídica.",
            ),
        ],
        highlight_box=(
            "PROMESSA CENTRAL (SEM SURPRESAS!)",
            "Custo total fechado em US$ e R$ (Produto + Frete Viajante + Tributos + Taxa 6%) com pagamento retido em custódia até a entrega.",
        ),
        footer_title="Conceito de Alto Nível (High-Level Concept)",
        footer_items=[
            "\"O Airbnb do espaço de bagagem aérea com despachante fiscal automatizado (PF/PJ) e custódia segura tipo Mercado Pago.\"",
        ],
        footer_ratio=0.20,
    )

    # -------------------------------------------------------------------------
    # BLOCO 9: VANTAGEM INJUSTA (Coluna 3, metade superior)
    # -------------------------------------------------------------------------
    draw_card(
        ax,
        x=col_x[3],
        y=top_row_y + half_h + half_gap_y,
        w=col_w,
        h=half_h,
        number="9",
        title="Vantagem Injusta",
        subtitle="Diferenciais difíceis de copiar",
        accent_color=GOLD_ACCENT,
        badge_bg=GOLD_BG,
        bullets=[
            (
                "Arquitetura Híbrida Nativa (PF + PJ)",
                "Isolamento estrito de contas pessoais e corporativas desde o banco de dados até a emissão documental para PMEs.",
            ),
            (
                "Solução do Gargalo Tributário",
                "Enquanto rivais operam na informalidade, o Trago! integra conformidade aduaneira e transparência fiscal na experiência.",
            ),
            (
                "Capital de Giro Positivo & Risco Zero",
                "Zero custo de estoque próprio; demanda e depósito em garantia ocorrem antes da execução do transporte.",
            ),
        ],
    )

    # -------------------------------------------------------------------------
    # BLOCO 5: CANAIS (Coluna 3, metade inferior)
    # -------------------------------------------------------------------------
    draw_card(
        ax,
        x=col_x[3],
        y=top_row_y,
        w=col_w,
        h=half_h,
        number="5",
        title="Canais",
        subtitle="Aquisição e distribuição",
        accent_color=NAVY,
        badge_bg=SKY_BG,
        bullets=[
            (
                "App Mobile Flutter (Android & Multiplataforma)",
                "Interface leve com mapa interativo global (flutter_map), catálogo curado, simulador fiscal e QR Code PIX.",
            ),
            (
                "Comunidades de Nicho & Milheiros",
                "Grupos de gamers, fotógrafos, colecionadores, intercambistas e fóruns de viajantes frequentes.",
            ),
            (
                "Parcerias B2B & Ecossistema de Inovação",
                "Hubs de startups, laboratórios de hardware/robótica e PMEs que importam componentes críticos.",
            ),
        ],
    )

    # -------------------------------------------------------------------------
    # BLOCO 2: SEGMENTOS DE CLIENTES (Coluna 4, altura inteira)
    # -------------------------------------------------------------------------
    draw_card(
        ax,
        x=col_x[4],
        y=top_row_y,
        w=col_w,
        h=top_row_h,
        number="2",
        title="Segmentos de Clientes",
        subtitle="Marketplace de dois lados (B2C + B2B)",
        accent_color=CORAL,
        badge_bg=CORAL_SOFT,
        bullets=[
            (
                "Compradores PF (Artigos > US$ 30)",
                "Consumidores de eletrônicos, áudio, fotografia e games de alto valor agregado (validado que itens < US$ 30 não compensam taxas).",
            ),
            (
                "Compradores PJ / PMEs",
                "Empresas que necessitam de importação emergencial de protótipos, placas (ex.: NVIDIA Jetson) e peças de reposição.",
            ),
            (
                "Viajantes Internacionais Verificados",
                "Passageiros em rotas de alta densidade (EUA, Europa, Japão → Brasil) com franquia de bagagem disponível.",
            ),
        ],
        footer_title="Adotantes Iniciais (Early Adopters)",
        footer_items=[
            "Gamers e entusiastas de tecnologia (20–40 anos).",
            "Estudantes/pesquisadores em intercâmbio (ex.: EACH-USP).",
            "PMEs de engenharia em São Paulo (corredor NY/Miami → GRU).",
        ],
        footer_ratio=0.28,
    )

    # -------------------------------------------------------------------------
    # BLOCO 7: ESTRUTURA DE CUSTOS (Base esquerda, 50% da largura)
    # -------------------------------------------------------------------------
    draw_card(
        ax,
        x=margin_x,
        y=bot_row_y,
        w=bot_col_w,
        h=bot_row_h,
        number="7",
        title="Estrutura de Custos (Cost Structure)",
        subtitle="Principais vetores de custo operacional, tecnológico e regulatório",
        accent_color=NAVY,
        badge_bg=SKY_BG,
        bullets=[
            (
                "Infraestrutura Cloud, Containers & APIs Públicas/Comerciais",
                "Hospedagem da API Backend (Node.js/Fastify + PostgreSQL isolados em containers), serviços de verificação de identidade (KYC/KYB), cotações cambiais e mapas.",
            ),
            (
                "Processamento Financeiro, Custódia (Escrow) & Antifraude",
                "Taxas de liquidação PIX/cartão junto ao PSP, manutenção das contas-garantia regulamentadas, seguro de transação e prevenção a disputas/chargebacks.",
            ),
            (
                "Aquisição de Usuários (CAC), Suporte Operacional & Compliance Aduaneiro",
                "Campanhas para equilibrar oferta de viajantes e demanda de compradores por corredor aéreo, mediação de disputas e assessoria jurídica/contábil PF/PJ.",
            ),
        ],
    )

    # -------------------------------------------------------------------------
    # BLOCO 6: FONTES DE RECEITA (Base direita, 50% da largura)
    # -------------------------------------------------------------------------
    draw_card(
        ax,
        x=margin_x + bot_col_w + gap_x,
        y=bot_row_y,
        w=bot_col_w,
        h=bot_row_h,
        number="6",
        title="Fontes de Receita (Revenue Streams)",
        subtitle="Modelo de monetização transacional validado no protótipo",
        accent_color=MINT_TEXT,
        badge_bg=MINT_BG,
        bullets=[
            (
                "Taxa de Serviço / Take-Rate da Plataforma (6% por Transação)",
                "Comissão percentual transparente aplicada sobre o pedido (validada na tela de Cálculo Fiscal do app: ex. US$ 21 em um pedido de US$ 300 + frete + tributos).",
            ),
            (
                "Comissão sobre Intermediação de Capacidade Logística (Frete por Kg)",
                "Spread operacional sobre a reserva de espaço na bagagem do viajante (tarifas de US$ 38/kg a US$ 48/kg conforme rota internacional e urgência).",
            ),
            (
                "Soluções Corporativas B2B & Serviços de Valor Agregado",
                "Emissão automatizada de dossiês contábeis para importação empresarial (PJ), gestão de múltiplos representantes por CNPJ e proteção estendida para cargas de alto valor.",
            ),
        ],
    )

    # Rodapé informativo
    ax.text(
        80.0,
        1.25,
        "Trago! Marketplace Cross-Border   •   Lean Canvas gerado programaticamente via Matplotlib (Python)   •   Repositório: github.com/TheHugoHypothesis/Trago",
        color=TEXT_MUTED,
        fontproperties=get_font("medium", 8.2),
        ha="center",
        va="center",
    )

    plt.subplots_adjust(left=0, right=1, top=1, bottom=0)

    png_path = output_dir / "LeanCanvas.png"
    pdf_path = output_dir / "LeanCanvas.pdf"
    svg_path = output_dir / "LeanCanvas.svg"

    fig.savefig(png_path, dpi=200, facecolor=BG_CANVAS)
    fig.savefig(pdf_path, facecolor=BG_CANVAS)
    fig.savefig(svg_path, facecolor=BG_CANVAS)
    plt.close(fig)
    print(f"Arquivos gerados com sucesso:\n - {png_path}\n - {pdf_path}\n - {svg_path}")


if __name__ == "__main__":
    out = Path(__file__).resolve().parent
    build_lean_canvas(out)
