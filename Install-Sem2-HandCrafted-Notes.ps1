param(
  [switch]$PushOta
)

$ErrorActionPreference = "Stop"
$u = New-Object System.Text.UTF8Encoding $false
$env:PYTHONIOENCODING = "utf-8"

$root = "C:\Users\khoda\OneDrive\Desktop\law-studyes-offline-apk-kit"
if (-not (Test-Path (Join-Path $root "www"))) { $root = (Get-Location).Path }
Set-Location $root

$dataDir = Join-Path $root "data"
New-Item -ItemType Directory -Path $dataDir -Force | Out-Null

$sem2Json = @'
{
  "subjects": [
    {
      "id": "family-law-ii",
      "title": "Family Law - II (Muslim Law)",
      "semester": "Semester 2",
      "url": "",
      "units": [
        {
          "unitNo": 1,
          "title": "Sources, Schools, Marriage (Nikah) & Dower (Mahr)",
          "topics": [
            {"id": "family-law-ii-u1-t1", "title": "1. Muslim Marriage (Nikah) - Essentials, Impediments & Muta Marriage"},
            {"id": "family-law-ii-u1-t2", "title": "2. Dower (Mahr) - Meaning, Kinds & Legal Nature"}
          ]
        },
        {
          "unitNo": 2,
          "title": "Divorce (Talaq), Dissolution & Maintenance",
          "topics": [
            {"id": "family-law-ii-u2-t1", "title": "1. Talaq - Modes of Divorce & Judicial Dissolution by Wife"}
          ]
        }
      ]
    },
    {
      "id": "law-of-crimes",
      "title": "Law of Crimes (IPC / BNS)",
      "semester": "Semester 2",
      "url": "",
      "units": [
        {
          "unitNo": 1,
          "title": "Concept of Crime, Stages & Theories of Punishment",
          "topics": [
            {"id": "law-of-crimes-u1-t1", "title": "1. Concept of Crime, Four Stages & Distinction from Tort and Contract"},
            {"id": "law-of-crimes-u1-t2", "title": "2. Theories of Punishment & Abetment"}
          ]
        },
        {
          "unitNo": 2,
          "title": "Offences Against the State & Sexual Offences",
          "topics": [
            {"id": "law-of-crimes-u2-t1", "title": "1. Sexual Offences, Custodial Rape & Modern Statutory Updates"}
          ]
        }
      ]
    },
    {
      "id": "law-of-evidence",
      "title": "Law of Evidence (IEA / BSA)",
      "semester": "Semester 2",
      "url": "",
      "units": [
        {
          "unitNo": 1,
          "title": "Nature, Applicability & Kinds of Evidence",
          "topics": [
            {"id": "law-of-evidence-u1-t1", "title": "1. Salient Features, Historical Background & Kinds of Evidence"},
            {"id": "law-of-evidence-u1-t2", "title": "2. Relevancy of Facts - Res Gestae, Alibi & Conspiracy (Sections 5-16)"}
          ]
        },
        {
          "unitNo": 2,
          "title": "Confessions, Documentary Evidence & Examination",
          "topics": [
            {"id": "law-of-evidence-u2-t1", "title": "1. Confessions, Primary vs Secondary Evidence & Cross-Examination"}
          ]
        }
      ]
    },
    {
      "id": "constitutional-law-ii",
      "title": "Constitutional Law - II",
      "semester": "Semester 2",
      "url": "",
      "units": [
        {
          "unitNo": 1,
          "title": "Union Executive & Parliamentary Responsibility",
          "topics": [
            {"id": "constitutional-law-ii-u1-t1", "title": "1. Principle of Collective Responsibility & Anti-Defection Law"}
          ]
        },
        {
          "unitNo": 2,
          "title": "Judiciary & Centre-State Legislative Relations",
          "topics": [
            {"id": "constitutional-law-ii-u2-t1", "title": "1. Supreme Court as a Court of Record & Judicial Accountability"},
            {"id": "constitutional-law-ii-u2-t2", "title": "2. Doctrine of Pith and Substance & Union-State Relations"}
          ]
        }
      ]
    }
  ],
  "notes": {
    "family-law-ii-u1-t1": {
      "id": "family-law-ii-u1-t1",
      "subtitle": "Family Law - II (Muslim Law) - Unit 1",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "Under Muslim law, marriage (Nikah) is a civil contract executed through offer (Ijab) and acceptance (Qubool) to legalize cohabitation and legitimize children. It requires free consent, competent parties, dower (Mahr), and absence of prohibited relationships.",
        "legalProvision": "Muslim Personal Law (Shariat) Application Act, 1937; Classical Hanafi and Shia principles of Nikah",
        "meaning": "Muslim marriage (Nikah) is legally a civil contract rather than a religious sacrament, though it carries religious significance. Its primary objectives are to legalize marital companionship and the procreation and legitimation of children. In Shia law, a temporary marriage for a fixed period and specified dower is recognized as Muta marriage.",
        "keyPoints": [
          "Offer (Ijab) and Acceptance (Qubool): Must be expressed clearly by the parties or their guardians at the same meeting.",
          "Free Consent and Competence: Both parties must be of sound mind, have attained puberty, and give consent without coercion or fraud.",
          "Dower (Mahr): A mandatory sum of money or property payable by the husband to the wife as a mark of respect.",
          "Witnesses and Nikahnama: Under Sunni law, two adult male witnesses (or one male and two female witnesses) must be present; Nikahnama serves as documentary proof.",
          "Impediments to Marriage: Marriage is barred within prohibited degrees of blood relationship (consanguinity), affinity (e.g., mother-in-law), fosterage (milk relationship), polyandry (woman having an existing husband), or during the woman's Iddat period.",
          "Fifth Marriage Rule: A Muslim male cannot contract a fifth marriage while four wives are living; under Sunni law such a marriage is irregular (Fasid) until one is divorced.",
          "Muta Marriage (Shia Law): A temporary contract for a fixed duration with fixed Mahr; it dissolves automatically on expiry without Talaq, children are legitimate, and the wife observes Iddat."
        ],
        "caseLaws": [
          {
            "name": "Abdul Kadir v. Salima",
            "citation": "1886 ILR 8 All 149",
            "principle": "Justice Mahmood held that Muslim marriage is a civil contract founded on mutual consent, creating reciprocal rights and obligations."
          }
        ],
        "selfTest": [
          {
            "q": "What are the essential requisites of a valid Muslim marriage (Nikah)?",
            "a": "Proposal (Ijab), acceptance (Qubool) at the same meeting, free consent of competent parties, dower (Mahr), absence of impediments, and witnesses under Sunni law."
          },
          {
            "q": "How does a Muta marriage end under Shia law?",
            "a": "It dissolves automatically upon expiry of the fixed period without requiring Talaq, though the wife must observe Iddat."
          }
        ],
        "visuals": []
      }
    },
    "family-law-ii-u1-t2": {
      "id": "family-law-ii-u1-t2",
      "subtitle": "Family Law - II (Muslim Law) - Unit 1",
      "readTime": "4 min read",
      "url": "",
      "en": {
        "inOneMinute": "Dower (Mahr) is a mandatory sum of money or property that a Muslim husband must pay to his wife in consideration of marriage. It is classified into Specified or Proper dower (by determination) and Prompt or Deferred dower (by time of payment).",
        "legalProvision": "Muslim Personal Law (Shariat) Application Act, 1937; Section 3, Muslim Women (Protection of Rights on Divorce) Act, 1986",
        "meaning": "Mahr (dower) is an obligation imposed by Islamic law upon the husband as a mark of respect for the wife and to provide her financial security during marriage or after its dissolution by death or divorce.",
        "keyPoints": [
          "Specified Dower (Mahr-i-Musamma): Fixed by mutual agreement before, at the time of, or after the marriage.",
          "Proper Dower (Mahr-i-Misl): If dower is not fixed at marriage, the wife is still entitled to a reasonable amount determined by the status of her paternal family, even if she agreed not to claim dower.",
          "Prompt Dower (Muajjal): Payable immediately on demand by the wife after marriage.",
          "Deferred Dower (Muwajjal): Payable upon dissolution of marriage either by the death of either spouse or by divorce.",
          "Wife's Remedies: An unpaid wife can sue for dower as an unsecured debt and, if lawfully in possession of her deceased husband's property, exercise the right of retention."
        ],
        "caseLaws": [
          {
            "name": "Maina Bibi v. Chaudhri Vakil Ahmad",
            "citation": "1925 PC 63",
            "principle": "A Muslim widow lawfully in possession of her husband's estate in lieu of unpaid dower has a right to retain possession until her dower debt is satisfied."
          }
        ],
        "selfTest": [
          {
            "q": "Distinguish between Prompt Dower and Deferred Dower.",
            "a": "Prompt dower (Muajjal) is payable immediately on demand, whereas deferred dower (Muwajjal) becomes payable upon dissolution of marriage by death or divorce."
          }
        ],
        "visuals": []
      }
    },
    "family-law-ii-u2-t1": {
      "id": "family-law-ii-u2-t1",
      "subtitle": "Family Law - II (Muslim Law) - Unit 2",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "Divorce under Muslim law may occur by the husband (Talaq-e-Ahsan, Talaq-e-Hasan, Ila, Zihar), by mutual consent (Khula or Mubarat), or by judicial decree sought by the wife under the Dissolution of Muslim Marriages Act, 1939. Instant triple talaq (Talaq-ul-Biddat) is void and illegal in India.",
        "legalProvision": "Dissolution of Muslim Marriages Act, 1939 (Section 2); Muslim Women (Protection of Rights on Marriage) Act, 2019",
        "meaning": "Talaq refers to the dissolution of a Muslim marriage contract. While classical law recognized extrajudicial modes of divorce, Indian statutory law and Supreme Court precedent protect wives through judicial divorce grounds and by declaring instant triple talaq unconstitutional and void.",
        "keyPoints": [
          "Talaq-e-Ahsan (Most Approved): A single pronouncement of talaq during a Tuhr (period of purity) followed by abstinence during the Iddat period; revocable before Iddat expires.",
          "Talaq-e-Hasan (Approved): Three pronouncements made across three successive monthly periods of purity without resumption of cohabitation.",
          "Talaq-ul-Biddat (Instant Triple Talaq): Three pronouncements at once; declared unconstitutional in Shayara Bano (2017) and void/punishable under the 2019 Act.",
          "Ila and Zihar: Constructive divorces where the husband swears abstinence for four months (Ila) or compares the wife to a prohibited female relative (Zihar).",
          "Khula: Divorce initiated by the wife with the husband's consent, typically documented in a Khulanama.",
          "Judicial Divorce by Wife (Section 2, 1939 Act): Grounds include husband's disappearance for 4 years, failure to maintain for 2 years, imprisonment for 7 or more years, impotency, insanity or virulent leprosy/venereal disease for 2 years, and cruelty."
        ],
        "caseLaws": [
          {
            "name": "Shayara Bano v. Union of India",
            "citation": "2017 9 SCC 1",
            "principle": "The Supreme Court held instant triple talaq (Talaq-ul-Biddat) to be manifestly arbitrary, unconstitutional, and void."
          }
        ],
        "selfTest": [
          {
            "q": "State four grounds on which a Muslim wife can obtain judicial divorce under Section 2 of the Dissolution of Muslim Marriages Act, 1939.",
            "a": "Husband missing for 4 years, failure to maintain for 2 years, sentence of imprisonment for 7+ years, and cruelty or impotency."
          }
        ],
        "visuals": []
      }
    },
    "law-of-crimes-u1-t1": {
      "id": "law-of-crimes-u1-t1",
      "subtitle": "Law of Crimes (IPC / BNS) - Unit 1",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "An offence is any act or omission prohibited by criminal law and punishable by the State with imprisonment or fine. Every crime progresses through four stages: Intention (Mens Rea), Preparation, Attempt, and Commission.",
        "legalProvision": "Section 40 and Section 511, Indian Penal Code, 1860 (Corresponding to Section 2(24) and Section 62, Bharatiya Nyaya Sanhita, 2023)",
        "meaning": "A crime is a public wrong committed against society and the State, prosecuted through state machinery (police and criminal courts). Under the maxim 'Actus non facit reum nisi mens sit rea', an act does not make a person guilty unless the mind is also guilty.",
        "keyPoints": [
          "Stage 1 - Intention (Mens Rea): Mental element such as dishonest intention or malice; mere intention without an overt act is not punishable.",
          "Stage 2 - Preparation: Arranging means to commit an offence; generally not punishable except for grave offences like waging war against the Government, preparation for dacoity, and counterfeiting coins or government stamps.",
          "Stage 3 - Attempt: A direct overt act toward committing the offence after preparation; punishable under Section 511 IPC (Section 62 BNS) or specific sections like Section 307 IPC (attempt to murder).",
          "Stage 4 - Commission: Completion of the prohibited act, attracting the full statutory punishment.",
          "Crime vs Tort: Crime is a codified public wrong against society punishable by imprisonment/fine via State prosecution; tort is largely uncodified civil wrong against an individual remedied by unliquidated damages.",
          "Crime vs Contract: Crime violates a right in rem without consent where Mens Rea is material; contract involves a right in personam based on mutual consent enforced in civil courts."
        ],
        "caseLaws": [
          {
            "name": "Abhayanand Mishra v. State of Bihar",
            "citation": "AIR 1961 SC 1698",
            "principle": "Distinguished preparation from attempt, holding that an attempt begins once the accused commits a direct overt act toward the offence with criminal intent."
          }
        ],
        "selfTest": [
          {
            "q": "In which exceptional offences is mere preparation punishable under Indian criminal law?",
            "a": "Waging war against the Government, preparation to commit dacoity, and counterfeiting coins or government stamps."
          }
        ],
        "visuals": []
      }
    },
    "law-of-crimes-u1-t2": {
      "id": "law-of-crimes-u1-t2",
      "subtitle": "Law of Crimes (IPC / BNS) - Unit 1",
      "readTime": "4 min read",
      "url": "",
      "en": {
        "inOneMinute": "Penology recognizes five major theories of punishment: Deterrent, Retributive, Preventive, Reformative, and Expiatory. Abetment occurs when a person instigates, conspires, or intentionally aids another in committing an offence.",
        "legalProvision": "Sections 107-120, Indian Penal Code, 1860 (Sections 45-60, Bharatiya Nyaya Sanhita, 2023)",
        "meaning": "Punishment is a sovereign function of the State aimed at maintaining social order and rehabilitating offenders. Criminal liability also extends beyond the principal offender to abettors who instigate, conspire, or intentionally assist in the commission of a crime.",
        "keyPoints": [
          "Deterrent Theory: Uses the fear of punishment to discourage both the offender (specific deterrence) and the general public (general deterrence) from committing crimes.",
          "Retributive Theory: Holds that punishment is a deserved consequence proportionate to the gravity of the wrong committed.",
          "Preventive Theory: Disables the offender from repeating crimes through imprisonment or disqualification.",
          "Reformative Theory: Focuses on rehabilitating and educating the offender to reintegrate into society; strongly favoured in modern Indian jurisprudence.",
          "Abetment (Section 107 IPC / Section 45 BNS): Committed in three ways: (1) instigating any person, (2) engaging in a conspiracy with an overt act, or (3) intentionally aiding by an act or illegal omission."
        ],
        "caseLaws": [
          {
            "name": "Bachan Singh v. State of Punjab",
            "citation": "AIR 1980 SC 898",
            "principle": "Balanced deterrent and reformative considerations by holding that the death penalty should be imposed only in the 'rarest of rare' cases."
          }
        ],
        "selfTest": [
          {
            "q": "What are the three modes of abetment under Indian criminal law?",
            "a": "Instigation, conspiracy (with an overt act), and intentional aiding."
          }
        ],
        "visuals": []
      }
    },
    "law-of-crimes-u2-t1": {
      "id": "law-of-crimes-u2-t1",
      "subtitle": "Law of Crimes (IPC / BNS) - Unit 2",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "Rape (Section 375 IPC / Section 63 BNS) is non-consensual sexual assault against a woman, with stricter punishment for custodial and gang rape. Note for exams: Adultery (Section 497 IPC) was struck down in 2018, and consensual adult acts under Section 377 IPC were decriminalized in 2018.",
        "legalProvision": "Sections 375, 376, 376(2), 376D IPC, 1860 (Corresponding to Sections 63, 64, 70 BNS, 2023)",
        "meaning": "Sexual offences protect bodily autonomy and dignity. Consent obtained through fear, fraud, intoxication, unsoundness of mind, or from a minor below 18 years is legally invalid. Custodial rape involves abuse of authority by police officers, public servants, jail staff, or hospital management.",
        "keyPoints": [
          "Rape (Section 375 IPC / Section 63 BNS): Sexual acts against a woman's will, without free consent, or with a girl under 18 years of age.",
          "Punishment (Section 376 IPC / Section 64 BNS): Rigorous imprisonment of not less than 10 years, extendable to imprisonment for life, plus fine.",
          "Custodial Rape (Section 376(2) IPC): Committed by police officers, public servants, or staff of jails, remand homes, or hospitals; attracts aggravated punishment and statutory presumption of absence of consent under Section 114A IEA (Section 120 BSA).",
          "Gang Rape (Section 376D IPC / Section 70 BNS): Where a woman is raped by one or more persons constituting a group acting in furtherance of common intention; punishable with minimum 20 years up to life imprisonment.",
          "Exam Update on Adultery (Section 497 IPC): Struck down as unconstitutional in Joseph Shine v. Union of India (2018); adultery remains a civil ground for divorce, not a crime.",
          "Exam Update on Section 377 IPC: Decriminalized for consensual acts between adults in Navtej Singh Johar v. Union of India (2018); non-consensual acts and bestiality remain punishable."
        ],
        "caseLaws": [
          {
            "name": "Tukaram v. State of Maharashtra (Mathura Rape Case)",
            "citation": "AIR 1979 SC 185",
            "principle": "Led directly to the Criminal Law (Amendment) Act, 1983, introducing strict custodial rape provisions and the presumption of absence of consent."
          },
          {
            "name": "Joseph Shine v. Union of India",
            "citation": "2019 3 SCC 39",
            "principle": "Struck down Section 497 IPC (adultery) as violative of Articles 14, 15, and 21 of the Constitution."
          }
        ],
        "selfTest": [
          {
            "q": "Why is custodial rape treated as an aggravated offence under Indian criminal law?",
            "a": "Because the offender abuses an official position of trust or custody, triggering a statutory presumption of absence of consent and enhanced minimum punishment."
          }
        ],
        "visuals": []
      }
    },
    "law-of-evidence-u1-t1": {
      "id": "law-of-evidence-u1-t1",
      "subtitle": "Law of Evidence (IEA / BSA) - Unit 1",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "The Indian Evidence Act, 1872 (drafted by Sir James Fitzjames Stephen, now replaced by the Bharatiya Sakshya Adhiniyam, 2023) is the lex fori procedural law governing how facts in issue and relevant facts are proved in civil and criminal courts.",
        "legalProvision": "Sections 1, 3, and 5, Indian Evidence Act, 1872 (Sections 1, 2, and 3, Bharatiya Sakshya Adhiniyam, 2023)",
        "meaning": "Derived from the Latin 'evidere' (to show clearly), evidence is the oral and documentary (including electronic) material produced before a court to prove or disprove facts in issue or relevant facts. It applies to judicial proceedings before civil and criminal courts, though not strictly to affidavits or arbitration proceedings.",
        "keyPoints": [
          "Historical Background: Drafted by Sir James Fitzjames Stephen and enforced on 1 September 1872 with 167 sections (modernized into the Bharatiya Sakshya Adhiniyam, 2023).",
          "Lex Fori: Law of evidence is the law of the forum (place of trial) and governs procedure.",
          "Facts in Issue (Section 3): Facts asserted by one party and denied by the other (framed as 'issues' in civil suits and 'charges' in criminal trials).",
          "Oral vs Documentary Evidence: Oral evidence consists of witness statements (must be direct under Section 60); documentary evidence includes written and electronic records.",
          "Direct vs Circumstantial Evidence: Direct evidence proves a fact without inference; circumstantial evidence proves surrounding facts from which the main fact is inferred (valid if the chain is complete).",
          "Best Evidence Rule: Oral evidence must be direct (Section 60), documents must be proved by primary evidence (Section 64), and hearsay evidence is generally inadmissible."
        ],
        "caseLaws": [
          {
            "name": "Sharad Birdhichand Sarda v. State of Maharashtra",
            "citation": "AIR 1984 SC 1622",
            "principle": "Laid down the five golden principles (Panchsheel) for convicting an accused solely on circumstantial evidence."
          }
        ],
        "selfTest": [
          {
            "q": "What is the Best Evidence Rule under the Law of Evidence?",
            "a": "Oral evidence must be direct (Section 60), documentary contents must be proved by primary evidence (Section 64), and hearsay evidence is excluded."
          }
        ],
        "visuals": []
      }
    },
    "law-of-evidence-u1-t2": {
      "id": "law-of-evidence-u1-t2",
      "subtitle": "Law of Evidence (IEA / BSA) - Unit 1",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "Sections 5 to 16 define legal relevancy of facts. Key doctrines include Res Gestae (Section 6: facts forming part of the same transaction), Things Said or Done by Conspirators (Section 10), and Plea of Alibi (Section 11).",
        "legalProvision": "Sections 5 to 16, Indian Evidence Act, 1872 (Sections 3 to 14, Bharatiya Sakshya Adhiniyam, 2023)",
        "meaning": "Relevancy is not proof itself, but the legal gateway determining which facts a court may consider to establish proof. Only facts declared legally relevant under the Act are admissible in evidence.",
        "keyPoints": [
          "Res Gestae (Section 6): Spontaneous facts or statements so closely connected with a fact in issue as to form part of the same transaction are admissible as an exception to the hearsay rule.",
          "Occasion, Cause, Effect, Opportunity (Section 7): Facts showing the occasion, cause, effect, or opportunity for an event are relevant.",
          "Motive, Preparation & Conduct (Section 8): Previous or subsequent conduct and motive of any party or accused are relevant.",
          "Test Identification Parade (Section 9): Facts establishing the identity of a person or thing (such as a TIP during investigation) are relevant to corroborate witness identification.",
          "Conspiracy (Section 10): Anything said, done, or written by one conspirator in reference to their common intention is relevant against all co-conspirators.",
          "Plea of Alibi (Section 11): Facts inconsistent with a fact in issue (such as the accused being elsewhere at the time of the crime) are relevant."
        ],
        "caseLaws": [
          {
            "name": "Rattan v. Reginam",
            "citation": "1971 3 All ER 801",
            "principle": "A spontaneous emergency telephone call made by a victim moments before death was held admissible as Res Gestae because there was no time for fabrication."
          }
        ],
        "selfTest": [
          {
            "q": "Why is Res Gestae (Section 6) treated as an exception to the hearsay rule?",
            "a": "Because spontaneous statements made contemporaneously with the event leave no opportunity for fabrication, ensuring high reliability."
          }
        ],
        "visuals": []
      }
    },
    "law-of-evidence-u2-t1": {
      "id": "law-of-evidence-u2-t1",
      "subtitle": "Law of Evidence (IEA / BSA) - Unit 2",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "Confessions are classified as Judicial, Extra-Judicial, Retracted, and Co-accused confessions. Documentary proof requires Primary Evidence (original document) unless Secondary Evidence is permitted under Section 65, while Cross-Examination tests witness credibility.",
        "legalProvision": "Sections 24-30, 62-65, 93, and 137-138, Indian Evidence Act, 1872 (Sections 22-24, 57-60, 96, and 142-143, BSA, 2023)",
        "meaning": "A confession is an admission of guilt by an accused; extra-judicial confessions made outside court require independent corroboration. Documents must ordinarily be proved by producing the original (primary evidence), and witness testimony is tested through examination-in-chief, cross-examination, and re-examination.",
        "keyPoints": [
          "Judicial Confession: Made voluntarily before a Magistrate or court in due course of legal proceedings; can form the sole basis of conviction if voluntary and truthful.",
          "Extra-Judicial Confession: Made outside court to any private person; weak evidence that requires independent corroboration.",
          "Confession to Police (Section 25): Inadmissible unless it leads to the discovery of a physical fact under Section 27.",
          "Primary Evidence (Section 62): The original document itself produced for court inspection.",
          "Secondary Evidence (Section 63 & 65): Certified copies, mechanical copies, counterparts, or oral accounts of contents—admissible only when the original is lost, destroyed, or in the adversary's possession.",
          "Patent Ambiguity (Section 93): Ambiguity apparent on the face of a document; oral evidence cannot be given to cure it.",
          "Cross-Examination (Section 137-138): Examination of a witness by the adverse party to test veracity, expose contradictions, and shake credit."
        ],
        "caseLaws": [
          {
            "name": "Pakala Narayana Swami v. Emperor",
            "citation": "AIR 1939 PC 47",
            "principle": "Defined confession as a statement that either admits the offence in terms or substantially admits all the facts constituting the offence."
          }
        ],
        "selfTest": [
          {
            "q": "When is secondary evidence of a document admissible in court?",
            "a": "Only when the original (primary evidence) is unavailable due to loss, destruction, possession by the opposite party, or being a public document under Section 65."
          }
        ],
        "visuals": []
      }
    },
    "constitutional-law-ii-u1-t1": {
      "id": "constitutional-law-ii-u1-t1",
      "subtitle": "Constitutional Law - II - Unit 1",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "Under Article 75(3), the Council of Ministers is collectively responsible to the Lok Sabha—they 'swim and sink together.' The Tenth Schedule (Anti-Defection Law, 1985) disqualifies legislators who defect or defy party whips.",
        "legalProvision": "Article 75(3) and Tenth Schedule (52nd Constitutional Amendment Act, 1985), Constitution of India",
        "meaning": "Collective responsibility is the bedrock of India's parliamentary democracy, ensuring that the Union Executive remains continuously accountable to the popularly elected House. The Anti-Defection Law reinforces parliamentary stability by curbing opportunistic floor-crossing.",
        "keyPoints": [
          "Collective Responsibility (Article 75(3)): Every minister must own and defend Cabinet decisions in Parliament; any minister who disagrees must resign.",
          "Swim and Sink Together: A vote of no-confidence passed in the Lok Sabha requires the entire Council of Ministers (including Rajya Sabha ministers) to resign.",
          "Prime Minister's Resignation: Resignation or death of the Prime Minister automatically dissolves the Council of Ministers.",
          "Anti-Defection Law (Tenth Schedule, 1985): Added by the 52nd Amendment to combat political defections.",
          "Grounds for Disqualification (Paragraph 2): (a) Voluntarily giving up membership of a political party, or (b) voting or abstaining from voting contrary to a party whip without prior permission.",
          "Deciding Authority: The Speaker (Lok Sabha/Assembly) or Chairman (Rajya Sabha/Council) decides disqualification petitions, subject to judicial review."
        ],
        "caseLaws": [
          {
            "name": "Kihoto Hollohan v. Zachillhu",
            "citation": "AIR 1993 SC 412",
            "principle": "Upheld the constitutional validity of the Tenth Schedule while holding that the Speaker's disqualification decision is subject to judicial review under Articles 136, 226, and 227."
          }
        ],
        "selfTest": [
          {
            "q": "What are the two main grounds for disqualification under Paragraph 2(1) of the Tenth Schedule?",
            "a": "Voluntarily giving up membership of the political party, and voting or abstaining contrary to the party's direction without prior permission."
          }
        ],
        "visuals": []
      }
    },
    "constitutional-law-ii-u2-t1": {
      "id": "constitutional-law-ii-u2-t1",
      "subtitle": "Constitutional Law - II - Unit 2",
      "readTime": "4 min read",
      "url": "",
      "en": {
        "inOneMinute": "Article 129 declares the Supreme Court a 'Court of Record' with perpetual evidentiary authority and power to punish for contempt. Judicial accountability balances judicial independence by ensuring judges remain answerable to the Constitution, law, and public trust.",
        "legalProvision": "Articles 124(4), 129, and 215, Constitution of India; Contempt of Courts Act, 1971",
        "meaning": "A Court of Record is a superior court whose acts and judicial proceedings are permanently enrolled for perpetual memory and testimony, carrying unquestionable evidentiary value. Judicial accountability ensures that independent judges adhere strictly to constitutional standards and ethical conduct.",
        "keyPoints": [
          "Court of Record (Article 129 - SC; Article 215 - HC): Proceedings are preserved permanently as authoritative precedents and conclusive evidence.",
          "Contempt Power: Includes inherent power to punish for civil contempt (wilful disobedience of orders) and criminal contempt (scandalizing or obstructing justice).",
          "Judicial Independence vs Accountability: Judges are insulated from executive/political pressure, yet remain accountable to the Constitution, appellate review, and parliamentary impeachment.",
          "Impeachment Mechanism (Article 124(4)): A Supreme Court or High Court judge can be removed only by the President after a special-majority address by both Houses of Parliament on grounds of proved misbehaviour or incapacity.",
          "Dimensions of Accountability: Open-court reasoned judgments, in-house judicial inquiry procedures, and constitutional standards of conduct."
        ],
        "caseLaws": [
          {
            "name": "In re Vinay Chandra Mishra",
            "citation": "1995 2 SCC 584",
            "principle": "Affirmed that the Supreme Court's power to punish for contempt under Article 129 is an inherent constitutional power to protect the administration of justice."
          }
        ],
        "selfTest": [
          {
            "q": "What are the two core attributes of the Supreme Court as a Court of Record under Article 129?",
            "a": "Its records have permanent evidentiary authority as precedent, and it possesses inherent power to punish for contempt of itself."
          }
        ],
        "visuals": []
      }
    },
    "constitutional-law-ii-u2-t2": {
      "id": "constitutional-law-ii-u2-t2",
      "subtitle": "Constitutional Law - II - Unit 2",
      "readTime": "4 min read",
      "url": "",
      "en": {
        "inOneMinute": "The Doctrine of Pith and Substance determines the true nature and essence of a statute when it appears to encroach upon another legislature's list under the Seventh Schedule. If the law substantially falls within the legislature's competence, incidental encroachment does not invalidate it.",
        "legalProvision": "Article 246 and Seventh Schedule (Union List, State List, Concurrent List), Constitution of India",
        "meaning": "Because legislative entries in the Seventh Schedule often overlap, courts apply the Doctrine of Pith and Substance to examine a statute as a whole—its object, scope, and effect—to identify its true character rather than its incidental impact.",
        "keyPoints": [
          "Meaning of Pith and Substance: 'Pith' means true nature or essence; 'substance' means the essential character of the legislation.",
          "Purpose: Prevents valid Union or State laws from being struck down merely because they incidentally touch upon a subject in another legislative list.",
          "Test Applied by Courts: Courts examine the enactment as a whole, its main object, and the scope of its provisions.",
          "Incidental Encroachment Permitted: If a State law in pith and substance relates to a State List entry, it remains valid even if it incidentally affects a Union List matter.",
          "Federal Balance: Preserves legislative flexibility across Union, State, and Concurrent Lists under Article 246."
        ],
        "caseLaws": [
          {
            "name": "State of Bombay v. F.N. Balsara",
            "citation": "AIR 1951 SC 318",
            "principle": "Upheld the Bombay Prohibition Act as valid under the State List in pith and substance, despite its incidental effect on the import of liquor (Union List)."
          },
          {
            "name": "Prafulla Kumar Mukherjee v. Bank of Commerce, Khulna",
            "citation": "AIR 1947 PC 60",
            "principle": "Upheld the Bengal Money-Lenders Act in pith and substance even though it incidentally affected promissory notes."
          }
        ],
        "selfTest": [
          {
            "q": "When does a statute survive a challenge under the Doctrine of Pith and Substance?",
            "a": "When its true nature and main object fall within the enacting legislature's allotted list, even if it incidentally trenches upon another list."
          }
        ],
        "visuals": []
      }
    }
  }
}
'@

$packPath = Join-Path $dataDir "sem2_handcrafted_pack.json"
[System.IO.File]::WriteAllText($packPath, $sem2Json, $u)

Write-Host "`n=== 1. Merging Hand-Crafted Semester 2 Pack into www/nyayasaral_db.json (Zero Overlap) ===" -ForegroundColor Cyan
$pyMerge = @'
import json, os, sys, time
from pathlib import Path

db_path = Path(sys.argv[1])
pack_path = Path(sys.argv[2])

db = json.loads(db_path.read_text(encoding="utf-8"))
pack = json.loads(pack_path.read_text(encoding="utf-8"))

subjects = db.setdefault("subjects", [])
notes = db.setdefault("notes", {})
subj_by_id = {s["id"]: s for s in subjects if isinstance(s, dict) and "id" in s}

added_subjs, added_topics = 0, 0
for s in pack["subjects"]:
    if s["id"] not in subj_by_id:
        subjects.append(s)
        subj_by_id[s["id"]] = s
        added_subjs += 1
    else:
        ex_s = subj_by_id[s["id"]]
        ex_tids = {t["id"] for u in ex_s.get("units", []) for t in u.get("topics", [])}
        for u in s.get("units", []):
            new_ts = [t for t in u.get("topics", []) if t["id"] not in ex_tids]
            if new_ts:
                ex_s.setdefault("units", []).append({"unitNo": len(ex_s["units"]) + 1, "title": u["title"], "topics": new_ts})

for tid, rec in pack["notes"].items():
    if tid not in notes:
        notes[tid] = rec
        added_topics += 1

out = json.dumps(db, ensure_ascii=False, separators=(",", ":"))
tmp = db_path.with_name(f"{db_path.name}.{os.getpid()}.tmp")
tmp.write_text(out, encoding="utf-8")
json.loads(tmp.read_text(encoding="utf-8"))
for i in range(10):
    try:
        os.replace(str(tmp), str(db_path))
        break
    except (PermissionError, OSError):
        time.sleep(0.3 * (i + 1))

print(f"[PASS] Merged Semester 2 Hand-Crafted Notes: +{added_subjs} subjects, +{added_topics} English topics (Total topics now: {len(notes)})")
'@

$tmpPy = Join-Path $env:TEMP "ls_merge_sem2.py"
[System.IO.File]::WriteAllText($tmpPy, $pyMerge, $u)
python -u $tmpPy (Join-Path $root "www\nyayasaral_db.json") $packPath
if ($LASTEXITCODE -ne 0) { throw "Merge failed!" }

if ($PushOta) {
  Write-Host "`n=== 2. Running Built-In EN -> TE/HI Auto-Converter & Deploying Live OTA ===" -ForegroundColor Cyan
  & (Join-Path $root "Push-LawStudyes-OTA.ps1") -Message "Added Hand-Crafted Semester 2 Subjects (Family Law II, Crimes, Evidence, Constitutional Law II) + Auto TE/HI"
}