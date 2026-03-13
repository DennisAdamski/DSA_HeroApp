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
      wirkung:
          'Ähnlich wie beim Hexe finden nimmt der Vertraute die magische '
          'Witterung eines Gegenstands auf, der längere Zeit im Besitz der '
          'Hexe gewesen sein muss und mit dem sie ein emotionales Band '
          'verbindet. Dabei ist die RK-Probe um 1 pro Meile Entfernung des '
          'Gegenstands erschwert, bei besonders vertrauten Gegenständen aber '
          'auch nach Maßgabe des Meisters um bis zu 7 Punkte erleichtert. '
          'Auch in diesem Fall erfährt der Vertraute etwas über die Richtung, '
          'in der sich der Gegenstand befindet, nicht aber über einen Weg, zu '
          'ihm hin zu gelangen.',
      kosten: '3 AsP',
      wirkungsdauer: 'RkP* SR',
      merkmale: 'Hellsicht',
      zauberdauer: '7 Aktionen',
      zielobjekt: 'Einzelobjekt',
      reichweite: 'RkW in Meilen',
      technik:
          'Der Vertraute berührt die Hexe an der Stirn und lässt sich von ihr '
          'ein emotionales Bild des gesuchten Gegenstands übermitteln. '
          'Anschließend bewegt er sich einmal im Kreis und lässt seine Sinne '
          'in alle Himmelsrichtungen schweifen.',
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
      wirkung:
          'Vertrautentiere sind besonders prächtige Exemplare ihrer Art und '
          'so beeindruckend, dass sie manchmal auch andere Tiere '
          'einschüchtern können. Mit diesem Zauber kann ein Vertrauter ein '
          'Tier der gleichen Art, also Eulenvögel inklusive Nachtwinde, '
          'Katzenartige, Schlangen, Kröten, Molche und Salamander etc., so '
          'sehr einschüchtern, dass es einen Angriff abbricht und sich '
          'schließlich sogar von dannen trollt, je nach RkP*. Welche Tiere '
          'genau von diesem Zauber betroffen sind, entscheidet der '
          'Spielleiter.',
      kosten: '5 AsP',
      wirkungsdauer:
          'Das Tier trollt sich und zeigt für mindestens RkP* x 2 SR keine '
          'Angriffslust gegenüber der Hexe und ihrem Vertrauten mehr',
      merkmale: 'Einfluss',
      zauberdauer: '2 Aktionen',
      zielobjekt: 'Einzelwesen',
      reichweite: '3 Schritt',
      technik:
          'Der Vertraute sucht Blickkontakt mit dem fremden Tier und beginnt '
          'ein regelrechtes Blickduell.',
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
      wirkung:
          'Der Vertraute erspürt die Richtung, in der sich seine Meisterin von '
          'ihm aus aufhält, indem er ihre ganz persönliche magische '
          'Ausstrahlung über eine große Entfernung aufnimmt. Dieser '
          'Zaubergeruch kann nur durch den Einsatz von Antimagie oder '
          'göttliches Eingreifen unterbunden werden. Der Vertraute setzt '
          'diesen Zauber von sich aus natürlich nur dann ein, wenn er die '
          'Hexe mit seinen normalen Sinnen nicht aufspüren kann. Ob er auch '
          'einen Weg zu der Hexe findet, kann von IN-Proben abhängig gemacht '
          'werden. Da der Zauber nicht allzu lange hält, kann der Vertraute '
          'gezwungen sein, ihn nach einer gewissen Zeit zu wiederholen, um '
          'nicht vom Kurs abzukommen.',
      kosten: '2 AsP',
      wirkungsdauer: 'RkP* SR',
      merkmale: 'Hellsicht',
      zauberdauer: '5 Aktionen',
      zielobjekt: 'Hexe',
      reichweite: 'RkW in Meilen',
      technik:
          'Der Vertraute bleibt starr auf der Stelle stehen und konzentriert '
          'sich ganz auf die Aura seiner Meisterin.',
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
      wirkung:
          'Das Hautgift der Kröte verwandelt sich in eine magische '
          'Flüssigkeit, die jedem, der sie berührt, eine Krötenhaut anhext. '
          'Die Haut um die Kontaktstelle herum sieht und fühlt sich wie die '
          'Haut der berührten Kröte an. Dies bedeutet für ihren Träger je 1 '
          'Punkt Abzug auf CH und FF, wenn die Hand davon betroffen ist. Sind '
          'andere Hautpartien betroffen, so können leicht andere Abzüge '
          'gelten. Die Haut kann nur mittels Antimagie oder durch '
          'Heilzauberei, die wenigstens 7 LeP bewirkt, wieder in den '
          'ursprünglichen Zustand versetzt werden.',
      kosten: '4 AsP',
      wirkungsdauer:
          'Das Hautgift bleibt RkP* KR magisch geladen, die Wirkung der '
          'Krötenhaut hält bis zur Heilung oder dem Brechen des Zaubers '
          '(permanent)',
      merkmale: 'Form',
      zauberdauer: '2 Aktionen',
      zielobjekt: 'Einzelwesen',
      reichweite: 'Selbst',
      technik:
          'Die Kröte erstarrt und konzentriert sich auf die drohende Gefahr.',
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
      wirkung:
          'Wenn die Kröte sich selbst oder ihre Meisterin von gefährlichen '
          'Gegnern angegriffen sieht, kann sie ihre gesamte zu diesem '
          'Zeitpunkt vorhandene Astralenergie in eine magische Entladung '
          'umsetzen, die bei den Opfern SP in Höhe der eingesetzten AsP '
          'verursacht und nur von einem GARDIANUM abgefangen oder einem '
          'SCHADENSZAUBER BANNEN unterbrochen werden kann. Die Kröte wendet '
          'immer ihre gesamte AE auf, sie kann den Krötenschlag also nicht '
          'dosieren. Bei mehreren Gegnern werden die SP gleichmäßig verteilt.',
      kosten: 'Alle AsP, siehe oben',
      wirkungsdauer: 'Augenblicklich',
      merkmale: 'Schaden',
      zauberdauer: '2 Aktionen',
      zielobjekt: 'Mehrere Einzelwesen',
      reichweite: 'RkW/2 Schritt',
      technik:
          'Die Kröte starrt das Opfer an und lässt ihre Zunge ein paar Finger '
          'weit aus ihrem Maul schnellen.',
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
      wirkung:
          'Ein Vertrauter kann einem Menschen, den er im Schlaf beobachtet, '
          'teilweise dessen Regeneration entziehen, mit einer Geschwindigkeit '
          'von 1 LeP pro SR. Die geraubten Punkte entsprechen maximal den '
          'RkP*, natürlich höchstens bis zum vom Schläfer erwürfelten Wert. '
          'Der Vertraute kann die gestohlene Regeneration seiner nächsten '
          'eigenen hinzufügen. Das Opfer hat währenddessen Alpträume von dem '
          'konkreten Tier, das den Schaden verursacht, könnte sich also bei '
          'einer Begegnung mit dem Tier vage an es erinnert fühlen.',
      kosten: '1 AsP',
      wirkungsdauer:
          'Der Raub dauert längstens RkP* SR, der Entzug hat natürlich '
          'augenblickliche Wirkung',
      merkmale: 'Einfluss, Verständigung',
      zauberdauer: '5 Aktionen',
      zielobjekt: 'Einzelperson',
      reichweite: 'RkW Schritt',
      technik:
          'Der Vertraute lässt sich an einem Ort nieder, von dem aus er das '
          'Opfer deutlich wahrnehmen kann, und bleibt dort bis zum Ende der '
          'Wirkungsdauer regungslos sitzen.',
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
      wirkung:
          'Der Vertraute nimmt die Stimmung eines Gesprächspartners auf, '
          'verstärkt diese Wahrnehmung und leitet sie so an seine Meisterin '
          'weiter. Hierdurch kann sich die Hexe ein Bild von der Gefühlslage '
          'ihres Gegenübers machen: Trauer, Freude, Feindseligkeit, Wut usw. '
          'sind deutlich zu spüren. Mit diesem Vertrautenzauber ist es sogar '
          'in Grenzen möglich, dass zwei Hexen stille Zwiesprache führen oder '
          'sich für ein Zauberritual aufeinander einstimmen. In diesem Fall '
          'müssen natürlich beide Vertrauten die entsprechende Astralenergie '
          'aufwenden.',
      kosten: '2 AsP pro Spielrunde',
      wirkungsdauer:
          'Nach AsP-Aufwand, maximal RkP* des Vertrauten in Spielrunden',
      merkmale: 'Hellsicht, Verständigung',
      zauberdauer: '2 Aktionen',
      zielobjekt: 'Einzelperson',
      reichweite: 'RkW in Schritt',
      technik:
          'Das Tier berührt die Hexe an beliebiger Körperstelle und blickt das '
          'Ziel des Zaubers an.',
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
      wirkung:
          'Erzeugt eine Tarnung, die den Auswirkungen des CHAMAELIONI '
          'entspricht. Wie auch bei diesem Zauber ist der Zauber gebrochen, '
          'sobald sich das getarnte Tier bewegt.',
      kosten: '2 AsP',
      wirkungsdauer: 'RkP* in SR',
      merkmale: 'Illusion',
      zauberdauer: '1 Aktion',
      zielobjekt: 'Einzelwesen, freiwillig',
      reichweite: 'Selbst',
      technik:
          'Das Tier kauert sich zusammen und presst sich flach gegen den '
          'Boden.',
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
      wirkung:
          'Der Vertraute leiht der Hexe seine Sinnesorgane. Je nach Tierart '
          'wird das Wahrnehmungsvermögen der Hexe dadurch beträchtlich '
          'erweitert und geschärft. Sie kann Dinge wahrnehmen, die sonst für '
          'menschliche Sinne unbemerkt geblieben wären.',
      kosten: '3 AsP + 2 AsP pro Spielrunde',
      wirkungsdauer: 'Nach AsP, max. RkP* SR',
      merkmale: 'Eigenschaften, Verständigung',
      zauberdauer: '5 Aktionen',
      zielobjekt: 'Hexe',
      reichweite: 'Berührung',
      technik:
          'Der Vertraute berührt die Hexe, schließt die Augen und verharrt, '
          'als würde er schlafen.',
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
      wirkung:
          'Auch bei diesem Zauber leiht der Vertraute der Hexe seine Sinne, '
          'jedoch muss er nicht die ganze Zeit mit ihr in körperlichem '
          'Kontakt stehen. Vielmehr schickt die Hexe ihn aus, um eine '
          'bestimmte Person, keinen Gegenstand, zu beobachten und dabei '
          'möglichst unentdeckt zu bleiben. Die Hexe versinkt derweil in eine '
          'tiefe Trance, um geistig bei ihrem Vertrauten zu sein. Sie kann ihm '
          'jedoch selbst keine Nachrichten oder Befehle übermitteln, sondern '
          'nur beobachten, und ist während der Zauberdauer nicht in der Lage, '
          'irgendetwas anderes zu unternehmen. Nur durch starke Schmerzen kann '
          'ihr Bewusstsein in ihren Körper zurückgeholt werden. Der Zauber '
          'endet spätestens, wenn der Abstand zwischen Hexe und Vertrautem zu '
          'groß wird. Sollte der Vertraute verletzt werden oder gar sterben, '
          'während die Hexe an seinen Sinnen Anteil hat, erleidet die Hexe '
          'für jeden SP einen Punkt Erschöpfung.',
      kosten: '7 AsP',
      wirkungsdauer: 'Maximal bis zum nächsten Sonnenauf- oder -untergang (A)',
      merkmale: 'Verständigung',
      zauberdauer: '5 Aktionen',
      zielobjekt: 'Hexe',
      reichweite:
          'Der Vertraute kann sich maximal RkW Meilen von der Hexe entfernen',
      technik: 'Der Vertraute berührt die Hexe und beide verharren regungslos.',
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
      wirkung:
          'Der Vertraute ruft die Tiere der Umgebung, die ihm ähneln, herbei, '
          'um über den Schlaf der Hexe zu wachen. Je nach Tierart flattern '
          'Rabenvögel aus dem Himmel heran und lassen sich in den Ästen über '
          'dem Lagerplatz oder dem Giebel der Hütte nieder, schleichen Katzen '
          'aus den Gassen und versammeln sich in der Nähe der Hexe, bevölkern '
          'ganze Heerscharen von Kröten, Unken und Fröschen nahegelegene '
          'Teiche und Gewässer und so weiter. Welche Tiere genau dem Ruf '
          'folgen und ob überhaupt welche in der Nähe sind, bestimmt der '
          'Spielleiter. Die tierischen Wächter werden nicht in einen Kampf '
          'eingreifen, aber durch laute Geräusche oder Berührungen auf '
          'drohende Gefahr aufmerksam machen. Sie verlassen sich dabei auf '
          'ihre natürlichen Sinne.',
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
      technik:
          'Schnelle und bewegliche Vertraute wie Katzen und Affen verlassen '
          'tatsächlich die Seite der Hexe, um auf die Suche nach ihren '
          'Verwandten zu gehen. Eher unbewegliche Vertraute wie Kröten und '
          'Spinnen kauern sich nieder und senden einen stummen Ruf aus.',
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
      wirkung:
          'Mit diesem Zauber ist das Vertrautentier in der Lage, Bilder, '
          'Gefühle und Beschreibungen telepathisch an die Hexe zu übermitteln. '
          'Die Kommunikation findet etwa wie unter dem Zauber TIERGEDANKEN '
          'statt und ähnelt in keiner Weise einer konkreten Sprache. Jedes '
          'Vertrautentier wird zudem die ihm wichtigsten Sinneseindrücke zum '
          'Beschreiben einer Person verwenden, so dass die Spielleiterin von '
          'der Hexe eine Intuitions-Probe verlangen kann, um die Eindrücke zu '
          'entschlüsseln. Da das Tier die menschliche Sprache verstehen kann, '
          'kann sich hierbei ein Zwiegespräch entwickeln, wobei die Hexe '
          'spricht, das Tier seine Aussagen aber telepathisch überträgt. Wenn '
          'das Tier einen permanenten Fluch überbringt, dann wird dem Opfer '
          'mit Hilfe dieses Zaubers mitgeteilt, welches die Bedingungen zum '
          'Brechen des Fluches sind.',
      kosten: '2 AsP',
      wirkungsdauer: 'So lange die Berührung nicht unterbrochen wird',
      merkmale: 'Verständigung',
      zauberdauer: '2 Aktionen',
      zielobjekt: 'Hexe',
      reichweite: 'Berührung',
      technik:
          'Das Tier kuschelt sich an die Hexe und konzentriert sich auf die '
          'Bilder, die es übertragen will.',
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
