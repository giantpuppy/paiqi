# 排期天菜 — Design System

> Based on Spotify Dark Immersive + Notion Pastel Accents

## Philosophy

Content-first dark interface. The UI recedes into shadow, letting show posters, performance schedules, and cast information become the visual focus. Designed for evening/low-light usage scenarios typical of theatergoing.

## Color Palette

### Background Layers (Spotify-style depth)
| Token | Hex | Usage |
|-------|-----|-------|
| Canvas | `#121212` | Deepest background (scaffold) |
| Surface-1 | `#181818` | Cards, panels, bottom sheets |
| Surface-2 | `#1F1F1F` | Buttons, input fields, interactive surfaces |
| Surface-3 | `#252525` | Elevated cards, selected states |
| Surface-4 | `#2A2A2A` | Hover states, dividers |

### Text Colors
| Token | Hex | Usage |
|-------|-----|-------|
| Text Primary | `#FFFFFF` | Main text, headings |
| Text Secondary | `#B3B3B3` | Labels, subtitles, inactive items |
| Text Tertiary | `#8A8F98` | Captions, hints, disabled |

### Brand & Status Colors
| Token | Hex | Usage |
|-------|-----|-------|
| Brand Primary | `#6B5BCD` | Primary CTA, active states, brand accent |
| Want to See | `#811FE2` | "想看" status, featured cast highlight |
| Bought | `#34D399` | "已买" status, success states |
| Upcoming | `#F54A45` | Today indicator, urgent items |
| Unmarked | `#9CA3AF` | Default/unmarked status |

## Typography

- **Font Family**: NotoSansSC (Chinese-optimized)
- **Weights**: Bold (700) for headings/buttons, Regular (400) for body
- **Scale**: Hero 24px/700, Section Title 18px/600, Body 16px/400, Caption 14px/400, Small 12px/400

## Components

### Buttons
- **Shape**: Pill-shaped (StadiumBorder)
- **Primary**: `#1F1F1F` bg, white text
- **Active/Brand**: `#6B5BCD` bg, white text
- **Outlined**: Transparent bg, `#7C7C7C` border

### Cards
- **Border Radius**: 8px
- **Background**: `#181818`
- **Hover/Press**: Background lightens to `#252525`
- **Shadow**: `rgba(0,0,0,0.3) 0px 8px 8px`

### Input Fields
- **Background**: `#1F1F1F`
- **Border**: `#4D4D4D`, 1px
- **Focused Border**: `#6B5BCD`
- **Border Radius**: 8px

### Bottom Sheets
- **Background**: `#181818`
- **Top Radius**: 16px
- **Drag Handle**: `#4D4D4D`
