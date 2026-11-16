import 'package:dsa_heldenverwaltung/domain/hero_rituals.dart';

/// Vollstaendiges Vertrautenmagie-Preset fuer heldenspezifische Ritualkategorien.
const HeroRitualCategory kVertrautenmagiePresetCategory = HeroRitualCategory(
  id: 'vertrautenmagie',
  name: 'Vertrautenmagie',
  knowledgeMode: HeroRitualKnowledgeMode.ownKnowledge,
  ownKnowledge: HeroRitualKnowledge(
    name: 'Vertrautenmagie',
    value: 3,
    learningComplexity: 'E',
  ),
  additionalFieldDefs: <HeroRitualFieldDef>[
    HeroRitualFieldDef(
      id: 'tierart',
      label: 'Tierart',
      type: HeroRitualFieldType.text,
    ),
    HeroRitualFieldDef(
      id: 'ritualprobe',
      label: 'Ritualprobe',
      type: HeroRitualFieldType.threeAttributes,
    ),
    HeroRitualFieldDef(
      id: 'erschwernis',
      label: 'Erschwernis',
      type: HeroRitualFieldType.text,
    ),
  ],
  rituals: <HeroRitualEntry>[
    HeroRitualEntry(
      name: 'Dinge aufspüren',
      wirkung: 'enc:3:EPKJhafoPfuvfTMRdA7B/rKk0gKaz+m2cpLCZsJyk6OXsGxRQhLTd5dPbon7oQzy2KokGVz5WdL7aJfLSjQpvvIFvktgqWgHFcF67aIhsCf0qnC1gZr+kd1cuEFsona+v31U+SnkfIkPt5IxKz6tYJeYbY3T54pOtXe+MpRFGJitLG2XqENL29GvmG5NHzy5dZYWzeLnWAae7AFRAu7nqHa1C6GXkSKnenyM2P2/ziCUpIKGlDO4AXhHy1ff9OYXz7/HOw6g017R20xMRJOaMSZUEzgYkW7/zWVZvxtfyW99fqNbIErRFt55eq1PgSUCeK5fx134PFmP5CFS0pT/u/vMofioQ3tJuRtSLq6sqJCPCNRjIWOodkXSKRQiMxsTU/rzT65bOo6mGLQaVKzo4siVMT5aQbMm9J79S69n5EIEB7BxgioIS4Q126ihrCt3cTeCILhZlybItfVLrXVHhrAObOJTz56bvMhGdBvPEgulvy73wCgJCoepb3CZ+LFmOJXC85S/4UObm86cEgVKl5n0s0+pBINplmfgLqGdbtMS+9FfINaHl1ybjaVIzl/7NeOdxbcibSDIOVBDQsVHfAbyqkIVxgEf47XqSQXN2y6n829JzPouYCDZB702aKXhlG81578w8yK93chbU0FQ9f+7n7SxuN3f6YZ+kSk2514jEXexyHvWHMToDPrQKDMYnRxxBetz9N25DtrHpgMmRaxdoYHv1pLY0+xsjiXWKCDU+Q5tLLj+7w==',
      kosten: '3 AsP',
      wirkungsdauer: 'RkP* SR',
      merkmale: 'Hellsicht',
      zauberdauer: '7 Aktionen',
      zielobjekt: 'Einzelobjekt',
      reichweite: 'RkW in Meilen',
      technik: 'enc:3:B4FfRUaiLEJsWaT8uuazdrIQMPO/4kiVqdmgnalGuTv7dDccPJ8suHcq34o8ncVhX3XCzH033hv3rnU/3Sc3c6lUV9Q5WBNjPPp546Eea+EIs9pZV4/yEhCQdcF/HLdGx8J8Pxj+ECrNG9L8aMdpDjfvLfD3dPV9wox3XQOi0oOByM6MYaPNw7ukyFw6ODe4Bqh/fIFWBhq9bhx6aMisLY3Fe81cqlYBi6e219TQpJebxzrDCCJtBFQKlvlxYYSHFe4Nq51W9F/NLLRCwFFdAfqsflpHXVV8ckRO9WlYEZdeeNQj5wdh15rhF/S0qgxBV3Ot5Rblv/uw2UW3/WKoDOKyNpMIJQ==',
      additionalFieldValues: <HeroRitualFieldValue>[
        HeroRitualFieldValue(fieldDefId: 'tierart', textValue: 'Alle'),
        HeroRitualFieldValue(
          fieldDefId: 'ritualprobe',
          attributeCodes: <String>['KL', 'IN', 'IN'],
        ),
        HeroRitualFieldValue(fieldDefId: 'erschwernis', textValue: '+ Mod.'),
      ],
    ),
    HeroRitualEntry(
      name: 'Erster unter Gleichen',
      wirkung: 'enc:3:5ym0IZjHEOj1+NOpWO6v3J5S2rIotQw+frUbnb/GPlSnILcQC3PdsY/6BZrh5Hg3EKR9xBQyDDbvzFDC30B0mAyXa3W/UB0jZEYPAXBqyeksR6ybpssD8L71HjafRmMiV85QZLH+47saixlD4lF5nWPotrcRWCWKCNvwHCi0wUPVkmXLJ/2QhKkbywjqpavKOOArkXxW54wBkXE42SPZs8Aw7QbKj3Xfa2TaeEn9So3kObS61VvnzJr2DRLhVLsoxxlG4WRI9YdOZRFqWl5qOf5VHagIamXw7D7jsYgezGQlNMb4IL+QMuxkl64WF17xDwfXl910eaZ0EGhsVQsCOZCQO2cS5RcsVqEvNflEqiAJ8GziwCV1owWBip1f8YQ9HAY/ihtrMZ4BOMkatk5DP4CT6/r8teX//KjBh3dFdKCn5oD+xuSd/pofTJZHsvfbLaxl7pSV4ZKF8uI9XiPnwkOxPBV36bqVRjUrPUK4/vb2J/AQWTE37FbokhrSVL4nvqwCnxPjtCacV40qchcix+bmyOEormHemLIK5OM+z4jIbqzp/mWUM6rpA/ScSNeCueIjCYL1s/Uw34ZKMT1mxq92EnCw8OnNTdMn306WrioKxECFgzSRjW+E54cRM64Ut+PbwEbUFgJhWJwqlkCGvpMsz9kU5uhnx8uW3IeKfyYzhsCphH6t3j4KxquGiSyWqGB76r3y6Q==',
      kosten: '5 AsP',
      wirkungsdauer:
          'Das Tier trollt sich und zeigt für mindestens RkP* x 2 SR keine '
          'Angriffslust gegenüber der Hexe und ihrem Vertrauten mehr',
      merkmale: 'Einfluss',
      zauberdauer: '2 Aktionen',
      zielobjekt: 'Einzelwesen',
      reichweite: '3 Schritt',
      technik: 'enc:3:hjvNLxzFTIPHvDIaafRv5Dkm2EOfiq++n3X/BkWAYrvzsKL277UMCDb2LJDAKJZrSOA2BG3QL3EE48h4h0mdVFuNXwLmKQt31FSvu9o5eJxx35aOhpHX8OPsp8ImFXLIM/nnOYeSSdZeb0rVQz2NcvxKOmu/KBkoTaw=',
      additionalFieldValues: <HeroRitualFieldValue>[
        HeroRitualFieldValue(fieldDefId: 'tierart', textValue: 'Alle'),
        HeroRitualFieldValue(
          fieldDefId: 'ritualprobe',
          attributeCodes: <String>['MU', 'MU', 'CH'],
        ),
        HeroRitualFieldValue(fieldDefId: 'erschwernis', textValue: '+ MR'),
      ],
    ),
    HeroRitualEntry(
      name: 'Hexe finden',
      wirkung: 'enc:3:C1mkY/UApymrkf133Gi3MAGv1CWcgOMT57pbDo8snbuGsXgRmfygpUOLeMom8U6Ry7dwIuJBUd3Xu7yffUMfMS7WHhaHdMqNUXs36J46poSYkhbyjpmk/zwkqP5YGQO8AvkVEAl3BiKbcPgoYTYJozZlgCBiVtbDEzWBcBtldHjknP+ZU7OY9xIgoL9TcMqfkOao6UtU0fcmuTWbFIvNe0CEgklkwW3NZM4nxr8hiPZFgV5SrRQZ2mhI/8gUje70uL8cj77SQ5GC/m0TPVDnThiKzZnOKlFGuG/p6wVlLH0b4DV/BnNDDkODUCBlh0ihaEzu/Q5mY6kg32kpw6Q+iupxNk5giaqvBB0xj6e7b7gU3H6hvfYXJv9lBopcSNMGMxNrVCJZ7Z4B5vgXqQYJMoHS0EPZeKzCsDcnJ7dy5e68jdGxm9ioDs0w/JvKTfUiwHNZpYmV4t9T1g106pm1M5pTlgpEoxDppgzvO8LrZvg6adapj8E5gTpgkAsNAI2WA3OWi32YfgSgu/TrXEyO5z3IZO1F7meCkpea1pXO706PUL4huHc605KidDqDvBOJUtcKq3aRNO/qKG0VRJYiqpAsUFSfNEIjMdv47r8kRHVesCyJeeNJ3Bk6l9BwIu7sl3N0sEaKdIPFnfEFPGNA2cQJvYwxHpieg2Pm7WM7urPdU0IbWWrsIC3S8dgeVWBeCxp/7mEifwAxoAaT+1SF1sj4btlhHfcU+DH+j6zXb8vkTS4JOWGNXTzwXM+V2kLIn0q7Q6jDzzKGVB8eyzOp7M26nlq+FMYDMMDHsJjmHe3ElfTBdpU4s9MVWcFlK8A4uVamoPXQv0izW7IveNPXqXhv8R0ewYLoBaRLZm1EYHX15EU26+wxyOvrdJGHCOHu6OZMpCbVVCfwZYdkEdq1XdOG',
      kosten: '2 AsP',
      wirkungsdauer: 'RkP* SR',
      merkmale: 'Hellsicht',
      zauberdauer: '5 Aktionen',
      zielobjekt: 'Hexe',
      reichweite: 'RkW in Meilen',
      technik: 'enc:3:arM5LikBe8tInoCQ5fmNSlRf0B5or7Hfz6odIcpWmTtXNDLR45+OqUkbC2X3BuS2C6tYE8xbpS8yI6u8M1YXdVrVc8y17f41NBWUJowKGpIxpFUetIcESUxJxHiACPa9aIn+EGnGGUqRq0PlaiELixDTN8AdTPglQLQRLc7RzB2+qasfAQs=',
      additionalFieldValues: <HeroRitualFieldValue>[
        HeroRitualFieldValue(fieldDefId: 'tierart', textValue: 'Alle'),
        HeroRitualFieldValue(
          fieldDefId: 'ritualprobe',
          attributeCodes: <String>['KL', 'IN', 'IN'],
        ),
        HeroRitualFieldValue(
          fieldDefId: 'erschwernis',
          textValue: '–7, pro Meile Abstand um 1 erschwert',
        ),
      ],
    ),
    HeroRitualEntry(
      name: 'Krötengift',
      wirkung: 'enc:3:DpfsWKcltqa4nJjklaEBxnz10GmEl6w6ig1HD36xXvEWjpCeMHVlH8MiWTsbNRUo/Bsrq537GFcKHhdC3ootOamxEIJdOy/oUaXOyEMwJy5rOyvpVcRc/v+nZAbq0OYy0FXNXD7NLX+IbtSP16Wg1ZNYii/VKjv7uzcCFFaat4G0ovLjqP8DyzKTSDruth+mr3jjIvv7kICuSHRP6gkAElh2D8DEGsQ4R7tyWmcLKWWvHWXnbLaCjWFaDzwd1wjqhPDeAHZIvd19+iWi56eBpx0SDiZS6Da2D42DZCC6hsbdRJGGRetl0jP8whfqhHuM18yez8CgUXiqnTm3U7C1eBFZUDO3jiG8aKXGKEGiVvojyoXgBaWf2btHI6hr//Xzx4UJWrP+725KCTSLf+unC+yvN9VVAwxkFYThbegKjUIeVsJSyJvh/4SqAgxA7jaVpFBpQk99DtFUrO/psPUOOjrjxYuyyTIiML2L/MgVsk7VL7mubfLInOKkRijqKhMCpSeax8pZb2Sylmxwd2kGszzZPpINWvy9sgf/KbUgh+/wSWlzd0T2iq0XXBYqyv72HP5Nc70L1Yaxu2yBLp8THnEQkrc/0msAwdRyI9TDhC3sLe8n+2tE0H8RVgzO53wBpi1rHXnEAw7FXCRaN5SZiaHyPGwXO52ZgIRt0NBb+0irfFjRUwLVSf2bTsWjPe03/C9H3P6tXYKZvK1h0ku0dUoxyQo02HdbmnjExPnnUfgk/3RuAPrvdlWF8g==',
      kosten: '4 AsP',
      wirkungsdauer:
          'Das Hautgift bleibt RkP* KR magisch geladen, die Wirkung der '
          'Krötenhaut hält bis zur Heilung oder dem Brechen des Zaubers '
          '(permanent)',
      merkmale: 'Form',
      zauberdauer: '2 Aktionen',
      zielobjekt: 'Einzelwesen',
      reichweite: 'Selbst',
      technik: 'enc:3:7fXXn7sH83P/Fy0lxZ2mDm8TYogFtHsM2Ks5Hs7V4iL9KvNCBM0zE/SJMuXQ/niUNKZLrOcsLyrl3tDEg+ubs4tUjdlWh0pZ+4/Fzy3tUKA89Q2B9GrwI/NLCk1zKg==',
      additionalFieldValues: <HeroRitualFieldValue>[
        HeroRitualFieldValue(fieldDefId: 'tierart', textValue: 'Nur Kröte'),
        HeroRitualFieldValue(
          fieldDefId: 'ritualprobe',
          attributeCodes: <String>['IN', 'CH', 'KO'],
        ),
      ],
    ),
    HeroRitualEntry(
      name: 'Krötenschlag',
      wirkung: 'enc:3:DJ3BnFOZ8FjT7yjMX2UcuJIb5ws0KqfKFb3RqtH9JlU20JKMBU8mMdJS/5EiC7ORC9ETn4AwTUAVkFy7JrhjXmPHhHDzb0caEoNLgKd57NX571MdSLtzWyz4gfITh5CymlFNEkNumMGzvHyTUKovF4yQ7Ce/d2/SSeAEo1D61H/DAvKUIcCCXkNHqVMbhhfdSsaGv6vDB3NbWIT/5qKOytpRWTnfWzeq4DAyBAWpvvQ3HIUHi1O35Q15Qde0pUBeMP7ZcVuAVfa99JXg1+dd+OMBs/PKnv6CvJi1EhUQ/YwJ95Cq3Ccdw/4vKsOk79DSktdKyUlPML4oBNQK9DZacca1nqitCG5Ol984xuoo8E/k5/2oC3Z2tHQuvf/X9rXNM99fq7TMuJSVrkyuURO+5ozAR3+ooa3tvA8POQCMIeJLnTIy5WNQW0NfWRM6eqDIRjCFymEAztGpAkIaF6b4/8NEQQ6dCOTLH1kOglp8ryp6VKkW3JyIu8YQ5nCdhNezro7AWTSauhDcjUMes1vCkyqzQNyVPqQx7SzlFf3qP/cHp5CfDIf8FNRtR0lzvasT2ixSFYok3PGFaC01H6lW8faQEPBN5bEOlWQZv26w9hJ7y3qnH7FESW+r/0D7P2Fg9fwSfGtsOggwDlfPUAWJlii2OadP14/G8KrrjwflZcizS95bOnS32kNTAQQCszeUiyTV+hIc84/U',
      kosten: 'Alle AsP, siehe oben',
      wirkungsdauer: 'Augenblicklich',
      merkmale: 'Schaden',
      zauberdauer: '2 Aktionen',
      zielobjekt: 'Mehrere Einzelwesen',
      reichweite: 'RkW/2 Schritt',
      technik: 'enc:3:ESjiXu7sFPBGOuzU5ohjj0p5b4AWAawe6AoMeCq25IrQyWGuWuC+0jpRREzevaU20OSZBZfnKJEQvdyiSFeF9yGx9r7XIQMOIQNtOO5MNaE8yKSHMn3tjePO+gzF6yts0oA7pzQ7ZJBTNKwGX+8kdVMV3qfKzdz95uK0pi/1MQ==',
      additionalFieldValues: <HeroRitualFieldValue>[
        HeroRitualFieldValue(fieldDefId: 'tierart', textValue: 'Nur Kröte'),
        HeroRitualFieldValue(
          fieldDefId: 'ritualprobe',
          attributeCodes: <String>['IN', 'CH', 'KK'],
        ),
      ],
    ),
    HeroRitualEntry(
      name: 'Schlaf rauben',
      wirkung: 'enc:3:aRKcVhgJ6hOnTpPUWH23W02bWLy5tp/CET0f4ZGZZQ4osmbrFPquBlh0uiqxtmvjkX96LFOz/Omg5aI9upiHl8oRIFwSXxpJaTyY4D0IGk5ZGc9EOIaEh5cbELwY1QpsHBQBmFgHe4NSpaEHdRrEH4FxEg8niEC6/7Iq5Kmui3TH22tMEzqOZ6zsSppGj2NQ1+jhK/UcrIGpce5GutmxsmKZGTnTE0oP+rfvrXa9/r2p+99w3zKans1tlcK5QQRPj8mz6tzXWgU0PUX9THFsfkELFZAWQe4husUtadCbyo+IfI5buA0aJbOL00StSFg73P8VDAa+yBcjVKqgK/HB/2boBQaR2dBcMqIU9O6KMa314e1hHR0bIyLp+gitt25/+GejLnvdc7s6TfuLWwqFRsWParwsxHhv/3CBiVIQlIZw91CDoejHi7BQd4WJEz1OomSMSdf7mnCbyYL9xCvjUm4TphJC4DoPh7Du3uU1nSYmZg7ZVSTaO5Efgux9rxDYbP2xG0sAjNc/7pqTu92LhHkQRkFsYFZMOD2roC20KAxm2TJiNSXUIJgcStC4Hc5WA0f1+X58WbxT4VAAk3O4LFIkZ1LkPziRIXxJ9VKs4aJatJoJejtOhC8/u50/smJAG4loVcxn8bUwKYwFN9XMWHllINkgcTNkRwBXzUZ6VwtUfPK0+pppf54cmVZH7eq0s1urdpyKAxkra/RTO6/nuelCbdg=',
      kosten: '1 AsP',
      wirkungsdauer:
          'Der Raub dauert längstens RkP* SR, der Entzug hat natürlich '
          'augenblickliche Wirkung',
      merkmale: 'Einfluss, Verständigung',
      zauberdauer: '5 Aktionen',
      zielobjekt: 'Einzelperson',
      reichweite: 'RkW Schritt',
      technik: 'enc:3:DYKgvXNOaGcAgMtVNeUTxevEL8VdHgc+S/m261/p/AJkgU9P9Syl52SqXwwUnUku5rmHEXyXjIv+8z862uuTekFy8dZafBBk1qP60PlNF5ttHGtLe3MVvUp0M8KU4WlETTwJR8kechooFxQRoqSJ0YtGL7J/BbvPfN2/X/++/OG20+dLjkBCbG6tbk3lGZKLTeq3/Fb0k4Aw0ILnDh07yWdjQQqeWnfUZDNxTSWgju5Kb0I7wK64nClSDVAf070=',
      additionalFieldValues: <HeroRitualFieldValue>[
        HeroRitualFieldValue(fieldDefId: 'tierart', textValue: 'Alle'),
        HeroRitualFieldValue(
          fieldDefId: 'ritualprobe',
          attributeCodes: <String>['KL', 'IN', 'KO'],
        ),
      ],
    ),
    HeroRitualEntry(
      name: 'Stimmungssinn',
      wirkung: 'enc:3:sb3osjggeUC+uebKj1L8SJDhs1RvGUk4QAKUHdS86sq+6X3iOBom5byCSQiwZC4iGnzLp+Zps1iqLq6xu1ia0mNQi+qFnTLjkbJak/1kt8w6f8HC2H1wWZV3mo3+s/LBacgDFmGzndYsNYK8oYlGFz97WXUfORy/6LZnK+uCkgucW+K4M1pq2YPTCq1LXEO51eMdsjEw+RQ3Ta50XtvawlCf10lqzfmnfbhVA+9qViMyn8SCdQcsqNfN4nIkKuYAIVRSjfhQPmtnu0w/bESgXkoCg2u78qqk60qNYY2/z9Xfj3zFqLiR8TwxU/bSAtsJMu8nNMEhJYFzX402DkJYLe/fmvoPHPLFeuvcy8SJJfW1XDzHNcL4xymTd7Fx4JufiPyAp1GCw/vAVUBcghuyQ7If1N9Qp1djAlpvhB1i6psYa0qrKJ62qpD6+NxJopVohoYn8hNJxtZ1Dqj6GX8M2P/RpBNEFF8quu9OZcj5cyWJGDqZhUygvNFWsaQZY6yvKmdT8AZEED6bMPau1Dv4ukoTgDxGRKlhSbGEtSUqo/Wp8gPDuKV4iwvT6niu7aq5a3deIcD9s7AVoqAuVKB9syYPG0rQ3KFBvJ2YjmW6YSFNHsexv6zGiE3JQubSratloYC26OVYNpjScRAoT4QjYrTp3y/mTDhvKr7NwRUoKrdSaSghGOgRqwFgxENlXIWkiDge+KzFhmWYQnUcUjTE3EBhN3/4lSCKlyRxurg+D27lUyUg6O346xeVIg==',
      kosten: '2 AsP pro Spielrunde',
      wirkungsdauer:
          'Nach AsP-Aufwand, maximal RkP* des Vertrauten in Spielrunden',
      merkmale: 'Hellsicht, Verständigung',
      zauberdauer: '2 Aktionen',
      zielobjekt: 'Einzelperson',
      reichweite: 'RkW in Schritt',
      technik: 'enc:3:lM7jlhYu8aykZ078d7cFZEvprXAOydTxpR/33w1RddNGuQ7x5Um1qrlMKzGGuNg6iOuClGiFXQXA1Vb1dA1B/arVRzzEYvdfHgYHPvMiAMD9FWYwo1ytJoh/otyegwzZVqvd8iBDRN/xa1+N5Ri1uuxr4SpcEg==',
      additionalFieldValues: <HeroRitualFieldValue>[
        HeroRitualFieldValue(fieldDefId: 'tierart', textValue: 'Alle'),
        HeroRitualFieldValue(
          fieldDefId: 'ritualprobe',
          attributeCodes: <String>['IN', 'IN', 'CH'],
        ),
      ],
    ),
    HeroRitualEntry(
      name: 'Tarnung',
      wirkung: 'enc:3:R1kGlc1DiHS0+1nxSEF3wxZi93u0ENZxbuzctiUhcewueUiSKMOL/wWjWuv7zdLrVI2tMY+NozV+s5zmYB5wAYTtKDc/0qbQqAm6m47hJmS3Re3hEyW1NmpH81Jj0v7YX33RU1IfZ/5m26iIBmtloewytPs5BOTEfZjgWAEJS1pQrtj8i1kknbZys0tJm23rjvbIjTZep7PqZpmOHJlBkeumwKlmXsYY1/Ft6su/TkdEVVc9J0Jf3jLXv743',
      kosten: '2 AsP',
      wirkungsdauer: 'RkP* in SR',
      merkmale: 'Illusion',
      zauberdauer: '1 Aktion',
      zielobjekt: 'Einzelwesen, freiwillig',
      reichweite: 'Selbst',
      technik: 'enc:3:y79PlbHb85XNJLLDPSH9qPbon4bQnnaSSrqdoLZxUdo6gk9InT1PMnJwaLWuZMQOTPdZe5tEyDB6KKkm6zoxehmfHRJBdcbazJ4PIt1eJN1BXaVxcnf0IJ9qM1j9M/M6',
      additionalFieldValues: <HeroRitualFieldValue>[
        HeroRitualFieldValue(
          fieldDefId: 'tierart',
          textValue: 'Kröte, Schlange, Spinne',
        ),
        HeroRitualFieldValue(
          fieldDefId: 'ritualprobe',
          attributeCodes: <String>['IN', 'IN', 'GE'],
        ),
      ],
    ),
    HeroRitualEntry(
      name: 'Tiersinne',
      wirkung: 'enc:3:vhWYowahGEEF9oBDBoW2+fSqQNg9Rk+Wk/MtOGPHmGcsQHg2xnH9ZUwnW6n1943IjivIKixmRtcG2XwWwv9K0d/7wGbWP/u9WjlPnAqOWIZCAanvgyn9KW6+d01oT7FTlW3HJ3M54MdxEZxUK39Tx5OCGkGvTzrHPe4DALFYDu2mc6gHjjA3MUp3FVOnaI6svUo8f/91g9W+CShLZ/mA3rJS9VkIaX0OxaHfLTG3TxHCUkAkLDW+XmncNJEfMhFY+wFy0BjJr35tQg2h38sAmdjfGG0zRCHBq644cflbtjQ/KOUOJmLoJ/7bkARMYUDW0PoZRyT0k8B1SZCt4d0WmtZY2+SssNK7DE6uDw==',
      kosten: '3 AsP + 2 AsP pro Spielrunde',
      wirkungsdauer: 'Nach AsP, max. RkP* SR',
      merkmale: 'Eigenschaften, Verständigung',
      zauberdauer: '5 Aktionen',
      zielobjekt: 'Hexe',
      reichweite: 'Berührung',
      technik: 'enc:3:rK+SSh4wvx0tpO70huKGvtoOSxaKtvCfyTTberTZWQKqqhY51jtmngd3IwEof1UTaFSl1us4Ha+wmHGaYuE0vdo/aHij3yI62Mv6QZDwPJLFVAQsEVYkjvH1uX+HdpZGl8Reve1SrlpwvbF1T5jnkAL1m2eFyA==',
      additionalFieldValues: <HeroRitualFieldValue>[
        HeroRitualFieldValue(fieldDefId: 'tierart', textValue: 'Alle'),
        HeroRitualFieldValue(
          fieldDefId: 'ritualprobe',
          attributeCodes: <String>['KL', 'IN', 'IN'],
        ),
      ],
    ),
    HeroRitualEntry(
      name: 'Ungesehener Beobachter',
      wirkung: 'enc:3:Fo6jbtWTAh5eRoSZZnwGiTwTYSGBRtYZ6H0g7VLQKld3A8asUdUYa77mP49N8Xb/nNhX7QhPHFKQoUu2PnAzI52+WJ8q6HDYxZPj00TiZBKRaiIDo/exsya6qIGIT9N0joZ7bCwDepQhhlr1rlHsr8HB3vCYmV9WsPBzeQys+wSNHE4NzsllIphi72b0LXGq+UwagkItq+n/hmJq6i14H1z3PwQmRbiWFXiTvcg6yrcMZ4lmIJ1ConvrI+QulKP9XGca2Mpa3ukhDGWlVLFS7kj5p1PC2AoNSWZ6YzkdrxpfT4KYzxG/YCmPkVbpX8BUE1Z/CGtUoRWDX6usiT4VT8t2RsC7U+SaLXIaoFDlzQgI8rZhg6baodO/TJERj8ZjuItRsGOtL7C1UYlJAty/EJs+9yuV8PudfFg0W1XD7/kueLa8kWpQt0QFMkaHO+IaEH88aOA1hYhiCvTz7XdWlvIvjamK9a9XmvW9XVHV4nA49RrYPwXwNUnA6dzyYMyY7UtwHo5IdWdNdKt+3qSxquk3U3wXd0k8KZ1sDduqFpKha5lbYLxjWsjg3KMF8VEwoQbsbkiki7uZ8faZoNajeRHXwc8kyBz93j6nFcJQkZpbzaMiqEA3ctAaF9QYFd7/mv3ykGBtoH8BHC+BWLBTXvicqOGIXGpqspvPNhrh9+o/8pYPaDDV7sOZlPYnqEHB5t9d7VDKuQWrhVAi6QbARE3JDeEuMqBH0o2ZADMK5SNzn2IBWgb8H42jbN+Hw3xL02XkyBXFMMO/5zlMvGGeUlRp6gNZ+t3Oo8zdphUpLmh/SJZYuddHSLK+ccKJzts4nuh5aQM0kt243PENbRAbedHTbW0ioItsPJSMT1lBORAEvFNGLxkiIui325cI/mujZg4Ap25HZQk2ScZOljBx06nfw7d8ACzkxH1uMcHWL3BFDJWd4UWQHohGGRJDPz1W8mt7OjiPKvMW0gd2jQAJHbFCpDgmq6C1N8zp1j3+Uwz8myxk0L92DeExze8xrZI4DpfLZn8/ePW47GRe6h4KYqI9hVosr2lnKdZezoPaRSESD5yu2TdYBp5gFmE6CpiAZIIViP8avjl8pnYcDr7d1SY7Tehfe6c5qAcwzJAT91prLcrEtFdIrxLyxQ1R3L6uRe4rmiYsvOkLRmW0f6rvPsx3Zt/LW9/zpUOOnDlD1VbbTI5UCFlLYeUaxROwEKbOhJP4rmR8',
      kosten: '7 AsP',
      wirkungsdauer: 'Maximal bis zum nächsten Sonnenauf- oder -untergang (A)',
      merkmale: 'Verständigung',
      zauberdauer: '5 Aktionen',
      zielobjekt: 'Hexe',
      reichweite:
          'Der Vertraute kann sich maximal RkW Meilen von der Hexe entfernen',
      technik: 'enc:3:037336WJ+B1oEsXUonD10Obbfpp9ofpvyz5NUAJTh4jA0VnkB3whUMW9PM0IKnc2S/U+3OL30NzFdXcbsRuNp+SLNk+Ulh1mNHLD281oZJWjKupa228QoWdGEA==',
      additionalFieldValues: <HeroRitualFieldValue>[
        HeroRitualFieldValue(fieldDefId: 'tierart', textValue: 'Alle'),
        HeroRitualFieldValue(
          fieldDefId: 'ritualprobe',
          attributeCodes: <String>['IN', 'IN', 'CH'],
        ),
      ],
    ),
    HeroRitualEntry(
      name: 'Wachsame Augen',
      wirkung: 'enc:3:nPlLAUXT6jBj2UgBAm+YGTqc5w9VlusN5RLzBNmYLn0JhHwepLSjFZSYxdN3WyGS3lwLHdBkVxTVEIqaeGf89wonq6nzNTitwlKOY727LJuUYNxF2aIJzJQHnUQBGJ7+kQ4RdbxXN4wNsMODsQHzD45jkOMfMxnG5RNNIoh4E48Y/ptO1IMJP3EYKgEsufQDOCxemztv4K05AbEYf6oXHeLCtzSSOyrJ4Vi9fl5ETDgJxIaefGPBf1Dy1ZBmy5aHhEz4VlRO4QNqKGo33MiSzc5/YxnQgSMyhHaEoEyVLvJAV9iyxqwT6XYJ/18Qo9hYs8wd2dmtpFpnszbwbbcA7f3vFAW4/2GI8AvjGtflo+jDKxrIPk0ODgKkVWdmCDRCxl0OEvX0n4WKq8ndlPu2uImKzUYplvvh+gyXnj4m7V5uUDMWkvHkg89bbk91YrBmCUxxIxu0cb/sYdbvQRbapckggYtl8z/NmwzX0680TNBMLnY6fo7Y162rJ1dfdd/G0Xb/4T1mCDV/4EF+dqfzyiVmIhmBloNHRQc1xQCDfbkWhVsEWcwcSbdbJhlGgbQfq6mYiQqFK4emqRitkVXv9RvMRjLPBTqhH9WoCLxDw9V9Q2xc/lTuxDpZMOwJMxlCsMLkds2/EjJXDtImcJSXVY5XG4WkV+mwKxJH7TAQ4fsTQ581jTOifWigoFxgQ4zSLmmHXUlyKVZ4qxIJR9EQ48d7DcWk1WjdffKYjJTaI1frju4aNqHwX1dxcgVe1ZsHZWYQKoYaTli4hIeKhgv8NNtm1R16qGN4CSmQJRwfIcg2D7lKqdoskgFbys25MeePql2IShgxza7tbHALkaasrUUS5GTXQIqorgymAcN7+mTgp0uq0p/i8vSvRxHKMVW19DhiT0/WcouJAXmfMU/hP0UAya2GLSe1KixpIjKM+ZZozhg99o3vkJLzgGjpS5iLt4GdiC+G4MVxfdhVwX7gxBL9Wl5Akn1H4fbKmkk9EHoJFbA2KnOLSpGUlc+5CDYDrmAZNqQ=',
      kosten: '5 AsP',
      wirkungsdauer:
          'Bis zum nächsten Sonnenauf- oder Sonnenuntergang, je nachdem was '
          'zuerst eintritt',
      merkmale: 'Einfluss, Verständigung',
      zauberdauer:
          'Bis die Tiere ankommen, vergehen bis zu 3 SR; der stumme Ruf einer '
          'Kröte oder Spinne dauert ca. 15 Aktionen',
      zielobjekt: 'Mehrere Einzelwesen',
      reichweite:
          'Die Tiere strömen aus bis zu RkW x 100 Schritt Entfernung herbei',
      technik: 'enc:3:l9cJHx6kWpKb2Dhq6J7lmlw8RjqUNmTikOuICQmdooxtKuh9WTHAOOTW632AkMj6bewhjsLaUQMmw1a3vGf7O+CN2ofmfQd/amo+je+9n+qudRn1qNnEuZpp/nQSzW8QHQ8oxX+wki1HlOb0yRY2+4ZohSIYy2MHKd1XCdl7CBy7PepXW4vsmFw0VtOVFyWDPdLKGo/VLKuNUE6kYm4NgpReIl/Hv9gFowL5WQFl5P61Kz/1ZKIy9zQ526QSDicG4zmlpzLjQK+RzGQcEP+5N06xLn9B3jqP9TrhgtjBoNz1FAEmyVj+adeZF4vOND1wrP4CMchBFCiYncCqR9vtctq9LPTa1b/ozLbmd4UoMa6F12BQdtin',
      additionalFieldValues: <HeroRitualFieldValue>[
        HeroRitualFieldValue(
          fieldDefId: 'tierart',
          textValue: 'Alle, aber nur Machtvolle Vertraute',
        ),
        HeroRitualFieldValue(
          fieldDefId: 'ritualprobe',
          attributeCodes: <String>['IN', 'IN', 'CH'],
        ),
      ],
    ),
    HeroRitualEntry(
      name: 'Zwiegespräch',
      wirkung: 'enc:3:fhQz2DtTd39vJnBxHunm/1+waFQ0Coj27+Kyp4HwYo1FopO7rZgM1ZEdJz9Orr+p8JYI3SnNWpDOA0Kem3/8v4AYvaV8owmCxNfZy6+HvBa6+x5Dw9j6lz9mH0Vlu3yYghkb2kBpZR+6BL3H+GfJD5BzbYEI/a56393qJOVRTDhUPV+RAJiqot70IURoHGpayMBWs7riiJ1U4I4zDQSZOS02y5+xzwxObzyeFsCEjkhLXtU1lrC0wOGIGzBJuK998y0wGHyHJWffKjgdJXgF3a0Pm2AtNKu1J10U9Ft5RJqwRIFHdjc0dvrP6MzaXGy28MfGGvLMgDT81u3GDW786RCN0iqYUO/2yXJVCcBJLa3650rmVClFjGeoS3uC6pHbmsobKkgzt5v6X/ak1XI22pRpEw+l7GqN/CrBhET+1mq9DOxBD09htmiupYJDw4btbr7PPB8QjOCPyxt99QrRo4YVnZiQOYUeyTKAZkIHv+SuKPyuZDFA0tWkh0KBwr8YlNgEh6RIIDrKR3wdio5dy4SBwONzt9WAltWB8MatTpxgVfif82QGzO2atvhomAV0rEIOybmU9svyZjz7LwJLgpY/7T93s0RfMLIAWayNvAYpa4clMXIeBsa2XAwngRg4l0RPu4eaP/WwZjww9F0KG8yVVuZ3eXwxQqR7z/7HRj9GDWHjXKsvqcWdYMExCMvcylBMiHh/pS3MGUiiGoCjSs+Va3LVU4cYLtDmaynCOhAkI1t/BfiyOedlQ52LmGAUnx3Blyb9Q1VeWJKFyyAcS4o/a2D2o6QpkUr1iTOKUub4nUTpGQXLDNeOMsuG6jTRv/ZjZGE351EhqCTXtoV0keGkAR5ZCeze8aonbfWvebX1fbu6WnMoHRzHtEbcNwWrODI6+HwUmuWCsaXRxe7nBNBJH9rrgkVs27tqLJu7wj0sedXS4PNh3xkgR7CH2njgSFv/mZz0Ih+41UdPNGiTlReHB0dCONAcqCmAtgJzy2+DURX0v5i8s9EBvxl5zODfhjZ1xBf5oFM4DxHS6Tr5Wk8IDjvtDmqjhKmaatEA0U1FfO0AplB3QA39jx7SqcxxMndE0D16PO1uFKD/qTQTKh2mEmCmrMHdFCwQOkBz',
      kosten: '2 AsP',
      wirkungsdauer: 'So lange die Berührung nicht unterbrochen wird',
      merkmale: 'Verständigung',
      zauberdauer: '2 Aktionen',
      zielobjekt: 'Hexe',
      reichweite: 'Berührung',
      technik: 'enc:3:T0LaoWQeS928lFUhpevk+nlT2rTUhIim/B7Q/CIc7JidY6M3BRM4RCLnItfv0kbgoCzg0sRbWXCrD1cgpUWqPPPXFAQrMqgyYVKKFsb1ZHEWnHmhQxM/nfizA3A/X8tED9Caxxc2CM2gOpLatzNfhb78FVq79JJgg5hrH3c=',
      additionalFieldValues: <HeroRitualFieldValue>[
        HeroRitualFieldValue(fieldDefId: 'tierart', textValue: 'Alle'),
        HeroRitualFieldValue(
          fieldDefId: 'ritualprobe',
          attributeCodes: <String>['KL', 'IN', 'IN'],
        ),
      ],
    ),
  ],
);
