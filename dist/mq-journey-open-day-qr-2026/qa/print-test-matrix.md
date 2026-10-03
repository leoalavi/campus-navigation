# MQ Journey Open Day QR physical print QA

Status: **PENDING PHYSICAL SIGN-OFF**

Machine QA has decoded every SVG, 2048×2048 PNG, 300-DPI poster render, and
independently cropped contact-sheet cell. The following tests require actual
paper plus current Android and iPhone hardware and must not be inferred from
screen-based decoding.

| Condition | Android | iPhone | Expected |
| --- | --- | --- | --- |
| Normal indoor lighting | ☐ | ☐ | Fast acceptance |
| Bright light | ☐ | ☐ | Acceptance |
| Partial shadow | ☐ | ☐ | Acceptance |
| Mild viewing angle | ☐ | ☐ | Acceptance |
| Intended installation distance | ☐ | ☐ | Acceptance |
| Reduced print size test | ☐ | ☐ | Record pass/fail boundary |

Reject any print with a cropped or obstructed quiet zone, wrong location card,
screen-only success, or unreliable acquisition at the intended distance.
