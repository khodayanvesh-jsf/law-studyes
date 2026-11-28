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

$sem3B2Json = @'
{
  "subjects": [
    {
      "id": "jurisprudence",
      "title": "Jurisprudence",
      "semester": "Semester 3",
      "url": "",
      "units": [
        {
          "unitNo": 2,
          "title": "Sources of Law - Custom, Precedent & Legislation",
          "topics": [
            {"id": "jurisprudence-u2-t1", "title": "1. Sources of Law - Custom, Precedent (Stare Decisis & Ratio Decidendi) & Legislation"}
          ]
        },
        {
          "unitNo": 3,
          "title": "Legal Rights, Duties & Legal Personality",
          "topics": [
            {"id": "jurisprudence-u3-t1", "title": "1. Legal Rights & Duties - Kinds of Rights & Legal Status of Unborn, Dead & Corporate Persons"}
          ]
        },
        {
          "unitNo": 4,
          "title": "Possession, Ownership, Liability & Theories of Punishment",
          "topics": [
            {"id": "jurisprudence-u4-t1", "title": "1. Possession vs Ownership, Civil & Criminal Liability & Five Theories of Punishment"}
          ]
        }
      ]
    },
    {
      "id": "law-of-property",
      "title": "Law of Property (TPA)",
      "semester": "Semester 3",
      "url": "",
      "units": [
        {
          "unitNo": 2,
          "title": "General Doctrines of Transfer (Sections 19-53A)",
          "topics": [
            {"id": "law-of-property-u2-t1", "title": "1. Vested vs Contingent Interest, Election, Ostensible Owner, Feeding the Grant, Lis Pendens & Part Performance"}
          ]
        },
        {
          "unitNo": 3,
          "title": "Sale, Mortgages, Marshalling, Contribution & Charges",
          "topics": [
            {"id": "law-of-property-u3-t1", "title": "1. Sale vs Agreement to Sell, Six Kinds of Mortgages (Sec. 58), Redemption, Foreclosure & Charges"}
          ]
        },
        {
          "unitNo": 4,
          "title": "Lease, Gift, Actionable Claims, Wills & Easements",
          "topics": [
            {"id": "law-of-property-u4-t1", "title": "1. Lease (Sec. 105-117), Gift (Sec. 122-129), Actionable Claims, Codicil & Easements Act, 1882"}
          ]
        }
      ]
    },
    {
      "id": "administrative-law",
      "title": "Administrative Law",
      "semester": "Semester 3",
      "url": "",
      "units": [
        {
          "unitNo": 2,
          "title": "Delegated Legislation & Doctrine of Ultra Vires",
          "topics": [
            {"id": "administrative-law-u2-t1", "title": "1. Delegated Legislation - Reasons, Kinds, Doctrine of Ultra Vires & Legislative/Judicial Controls"}
          ]
        },
        {
          "unitNo": 3,
          "title": "Principles of Natural Justice & Fair Hearing",
          "topics": [
            {"id": "administrative-law-u3-t1", "title": "1. Principles of Natural Justice - Rule Against Bias (Nemo Judex) & Audi Alteram Partem"}
          ]
        },
        {
          "unitNo": 4,
          "title": "Writs, Tribunals, State Liability, Promissory Estoppel & Lokpal",
          "topics": [
            {"id": "administrative-law-u4-t1", "title": "1. Five Constitutional Writs, Administrative Tribunals, State Liability (Arts. 299-300), Public Corporations & Lokpal"}
          ]
        }
      ]
    },
    {
      "id": "company-law",
      "title": "Company Law",
      "semester": "Semester 3",
      "url": "",
      "units": [
        {
          "unitNo": 2,
          "title": "Promoters, Incorporation, Prospectus, Shares & Debentures",
          "topics": [
            {"id": "company-law-u2-t1", "title": "1. Promoters, Incorporation, Prospectus Misstatement, Kinds of Shares, Dividends & Debentures"}
          ]
        },
        {
          "unitNo": 3,
          "title": "Directors & Company Meetings",
          "topics": [
            {"id": "company-law-u3-t1", "title": "1. Board of Directors (Powers u/s 179 & Duties u/s 166) & Company Meetings (AGM, EGM, Resolutions)"}
          ]
        },
        {
          "unitNo": 4,
          "title": "Oppression, Mismanagement & Winding Up",
          "topics": [
            {"id": "company-law-u4-t1", "title": "1. Rule in Foss v. Harbottle, Oppression & Mismanagement (Secs. 241-242) & Winding Up / Liquidator"}
          ]
        }
      ]
    },
    {
      "id": "labour-law-i",
      "title": "Labour Law - I",
      "semester": "Semester 3",
      "url": "",
      "units": [
        {
          "unitNo": 2,
          "title": "Trade Union Registration, Funds, Amalgamation & Collective Bargaining",
          "topics": [
            {"id": "labour-law-i-u2-t1", "title": "1. Trade Union Registration, General & Political Funds, Amalgamation, Cancellation & Collective Bargaining"}
          ]
        },
        {
          "unitNo": 3,
          "title": "Industry Definition, Settlement Authorities & Chapter V-B",
          "topics": [
            {"id": "labour-law-i-u3-t1", "title": "1. Definition of Industry (Triple Test), ID Act Authorities & Prior Permission for Lay-Off/Retrenchment (Secs. 25M & 25N)"}
          ]
        },
        {
          "unitNo": 4,
          "title": "Standing Orders, Domestic Enquiry & Factories Act, 1948",
          "topics": [
            {"id": "labour-law-i-u4-t1", "title": "1. Standing Orders Act, 1946, Domestic Enquiry & Factories Act, 1948 (Health, Safety, Welfare & Young Persons)"}
          ]
        }
      ]
    }
  ],
  "notes": {
    "jurisprudence-u2-t1": {
      "id": "jurisprudence-u2-t1",
      "subtitle": "Jurisprudence - Unit 2",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "The three primary legal sources of law are Legislation (enacted by Parliament/State Legislatures), Precedent (binding judicial decisions under Article 141 and Stare Decisis), and Custom (immemorial community usages recognized by law).",
        "legalProvision": "Articles 141 and 245, Constitution of India; Classical Sources of Law (Salmond)",
        "meaning": "Legislation is the supreme modern source because it is deliberate, codified, and prospective. Judicial Precedent creates binding legal principles through Ratio Decidendi (reason for the decision), while Obiter Dicta (incidental remarks) carries persuasive weight. Custom remains valid only when ancient, certain, continuous, reasonable, and not contrary to statute.",
        "keyPoints": [
          "Legislation (Supreme vs Subordinate): Supreme legislation proceeds from Parliament or State Legislatures; Subordinate legislation includes Executive, Judicial, Municipal, Autonomous, and Colonial rule-making.",
          "Requisites of Valid Custom: Must be immemorial (ancient), certain, continuously and peacefully observed, reasonable, and not opposed to statutory law or public policy (e.g., Sati and dowry are prohibited).",
          "Kinds of Custom: General custom (across the country), Local custom (region/community specific), Legal custom (binding law like Saptapadi or Mahr), and Conventional custom (trade usages).",
          "Kinds of Precedent: Original (creates a new rule), Declaratory (applies an existing rule under Stare Decisis), Authoritative (binding on lower courts, e.g., SC decisions under Article 141), and Persuasive (non-binding Obiter Dicta or foreign/other High Court rulings).",
          "Ratio Decidendi vs Obiter Dicta: Ratio Decidendi is the binding legal principle necessary to decide the case; Obiter Dicta are incidental observations useful for law reform and persuasive reasoning.",
          "Codification Advantages: Brings certainty, accessibility, uniformity, and easier judicial application compared to scattered judge-made rules."
        ],
        "caseLaws": [
          {
            "name": "Bengal Immunity Co. Ltd. v. State of Bihar",
            "citation": "AIR 1955 SC 661",
            "principle": "Held that while Supreme Court judgments bind all Indian courts under Article 141, the Supreme Court itself is not bound by its own prior erroneous decisions and may overrule them."
          }
        ],
        "selfTest": [
          {
            "q": "Distinguish between Ratio Decidendi and Obiter Dicta in judicial precedent.",
            "a": "Ratio Decidendi is the core legal reasoning necessary to decide the dispute and binds subordinate courts, whereas Obiter Dicta are incidental judicial remarks that have only persuasive value."
          }
        ],
        "visuals": []
      }
    },
    "jurisprudence-u3-t1": {
      "id": "jurisprudence-u3-t1",
      "subtitle": "Jurisprudence - Unit 3",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "A Legal Right is an interest recognized and protected by a rule of law, always correlated with a corresponding Legal Duty. Legal personality is conferred not only on natural human beings, but also on artificial juristic persons such as companies, universities, trusts, and idols.",
        "legalProvision": "Salmond's Theory of Legal Rights & Corporate Personality; Sections 297 & 312 IPC (Sections 301 & 88 BNS, 2023); Section 13 TPA",
        "meaning": "Rights and duties are two sides of the same coin: every enforceable right imposes a correlative duty on another person or the State. Law also grants contingent rights to unborn children (contingent upon live birth) and protects the dignity, Will, and burial of dead persons.",
        "keyPoints": [
          "Correlative Nature of Rights and Duties: A right in rem (against the whole world, e.g., property/reputation) or right in personam (against a specific individual, e.g., contract debt) always carries a corresponding duty.",
          "Key Classifications of Rights: Perfect vs Imperfect (time-barred debt), Positive vs Negative, Vested vs Contingent, Corporeal (tangible property) vs Incorporeal (IPR), Right in re propria (own property) vs Right in re aliena (easement/mortgage over another's property), and Legal vs Equitable.",
          "Legal (Juristic) Persons: Artificial entities—Companies/Corporations, Universities, Wakfs, Trusts, and Hindu Idols—that can own property, contract, sue, and be sued in their own name.",
          "Legal Status of Unborn Person: Holds contingent personality subject to live birth—protected against forced miscarriage (Section 312 IPC / Section 88 BNS), execution of a pregnant mother is postponed, property may be settled for him (Section 13 TPA), and he can reopen partition upon birth.",
          "Legal Status of Dead Person: Personality ceases at death, but law protects decent burial, punishes indignity to a corpse (Section 297 IPC / Section 301 BNS), enforces his valid Will, and bars defamation hurting living relatives."
        ],
        "caseLaws": [
          {
            "name": "Pramatha Nath Mullick v. Pradyumna Kumar Mullick",
            "citation": "AIR 1925 PC 139",
            "principle": "Held that a Hindu idol is a juristic legal person capable of holding property and suing or being sued through its Shebait (manager)."
          }
        ],
        "selfTest": [
          {
            "q": "Distinguish between Right in re propria and Right in re aliena, and state two legal protections granted to an unborn person.",
            "a": "Right in re propria is ownership over one's own property, while Right in re aliena is an encumbrance (like an easement or mortgage) over another's property. An unborn child is protected by postponing a pregnant woman's death sentence and permitting property settlement contingent on live birth."
          }
        ],
        "visuals": []
      }
    },
    "jurisprudence-u4-t1": {
      "id": "jurisprudence-u4-t1",
      "subtitle": "Jurisprudence - Unit 4",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "Possession is de facto physical control (Corpus) coupled with the intention to exclude others (Animus), whereas Ownership is the supreme de jure legal right over property. Breach of legal duties triggers Civil or Criminal Liability, enforced through five classical theories of punishment.",
        "legalProvision": "Salmond's Theory of Possession & Ownership; Section 6, Specific Relief Act, 1963; Criminal & Civil Liability Principles",
        "meaning": "Possession is 'nine points of law' because peaceful possession is protected against forcible dispossession even against the true owner without due process. Ownership encompasses the right to possess, use, transfer, and dispose of property.",
        "keyPoints": [
          "Two Elements of Possession: Corpus Possessionis (physical control) and Animus Possidendi (mental intention to hold exclusively); acquired by Taking, Delivery, or Operation of Law.",
          "Kinds of Possession & Ownership: Corporeal vs Incorporeal, Mediate (through agent/carrier) vs Immediate, Adverse Possession, Concurrent Possession; Ownership includes Absolute vs Conditional, Vested vs Contingent, and Co-ownership vs Joint Ownership.",
          "Possession vs Ownership: Possession is de facto (may be lawful or unlawful) with limited rights; Ownership is de jure (always lawful) conferring full residuary control.",
          "Kinds of Liability: Civil Liability (remedied by damages/injunction in civil courts, Mens Rea generally immaterial), Criminal Liability (punished by imprisonment/fine via State prosecution where Mens Rea is vital), Vicarious Liability (master for servant), Strict/Absolute Liability, and Quasi-contractual Liability.",
          "Five Theories of Punishment: Deterrent (creating fear of crime), Preventive (disabling offender), Reformative (rehabilitating offender—favoured in modern Indian jurisprudence), Retributive (proportionate vengeance), and Expiatory (repentance)."
        ],
        "caseLaws": [
          {
            "name": "Bridges v. Hawkesworth",
            "citation": "1851 21 LJ QB 75",
            "principle": "Held that a customer who found banknotes on a public shop floor had better possessory title than the shopkeeper because the shopkeeper lacked Animus (intention) over lost items unknown to him."
          }
        ],
        "selfTest": [
          {
            "q": "What are the two essential elements of Possession, and how does Possession differ from Ownership?",
            "a": "Corpus (physical control) and Animus (intention to exclude others). Possession is de facto control (lawful or unlawful), whereas Ownership is the supreme de jure legal title."
          }
        ],
        "visuals": []
      }
    },
    "law-of-property-u2-t1": {
      "id": "law-of-property-u2-t1",
      "subtitle": "Law of Property (TPA) - Unit 2",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "Sections 19-53A of the Transfer of Property Act codify seven vital equitable doctrines: Vested vs Contingent Interest, Election (Section 35), Ostensible Owner (Section 41), Feeding the Grant by Estoppel (Section 43), Lis Pendens (Section 52), Fraudulent Transfer (Section 53), and Part Performance (Section 53A).",
        "legalProvision": "Sections 19, 21, 35, 41, 43, 52, 53, and 53A, Transfer of Property Act, 1882",
        "meaning": "These doctrines protect bona fide purchasers for value, prevent transferors from profiting from fraud or contradicting their own grants, and preserve disputed property during pending litigation.",
        "keyPoints": [
          "Vested vs Contingent Interest (Sections 19 & 21): A Vested interest takes effect immediately without an uncertain condition (heritable and transferable); a Contingent interest depends on a specified uncertain future event (Condition Precedent vs Condition Subsequent).",
          "Doctrine of Election (Section 35): Based on 'approbate and reprobate'—if a transferor professes to transfer another person's property and in the same instrument confers a benefit on that owner, the owner must elect either to confirm the transfer or dissent and forfeit the benefit.",
          "Transfer by Ostensible Owner (Section 41): A transfer for consideration by an apparent owner (acting with express or implied consent of the real owner) binds the real owner if the transferee took reasonable care and acted in good faith.",
          "Feeding the Grant by Estoppel (Section 43): If a person fraudulently or erroneously represents authority to transfer immovable property for consideration and later acquires title to it, the transferee can compel the transfer to operate on the newly acquired interest.",
          "Doctrine of Lis Pendens (Section 52): During the pendency of a bona fide, non-collusive suit involving a right to immovable property, neither party can transfer the property so as to affect the opponent's rights; any pendente lite transferee is bound by the court's decree.",
          "Fraudulent Transfer (Section 53) & Part Performance (Section 53A): Transfers made to defeat or delay creditors are voidable (Section 53); under Section 53A, a transferee who takes possession in part performance of a written, signed contract for consideration is shielded against eviction by the transferor (used as a shield, not a sword)."
        ],
        "caseLaws": [
          {
            "name": "Ramcoomar Koondoo v. Macqueen",
            "citation": "1872 11 Beng LR 46 (PC)",
            "principle": "Laid down the equitable foundation of Section 41 (Ostensible Owner): where the true owner allows another to hold himself out as owner, a bona fide purchaser for value is protected."
          },
          {
            "name": "Bellamy v. Sabine",
            "citation": "1857 1 De G&J 566",
            "principle": "Explained that the Doctrine of Lis Pendens rests on public necessity—preventing endless litigation by ensuring parties cannot alienate disputed property while a suit is pending."
          }
        ],
        "selfTest": [
          {
            "q": "Explain the core rule behind Doctrine of Election (Section 35) and Doctrine of Part Performance (Section 53A).",
            "a": "Under Section 35, one cannot accept a benefit under an instrument while rejecting its burden (approbate and reprobate). Under Section 53A, a transferee in possession under a written contract for consideration can defend his possession against the transferor."
          }
        ],
        "visuals": []
      }
    },
    "law-of-property-u3-t1": {
      "id": "law-of-property-u3-t1",
      "subtitle": "Law of Property (TPA) - Unit 3",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "Sale (Section 54) transfers absolute ownership for a price, whereas a Mortgage (Section 58) transfers an interest in specific immovable property to secure a loan across six statutory kinds. Section 60 guarantees the mortgagor's Right of Redemption ('once a mortgage, always a mortgage'), while Section 100 defines a Charge.",
        "legalProvision": "Sections 54, 58, 60, 67, 81, 82, and 100, Transfer of Property Act, 1882",
        "meaning": "Unlike an Agreement to Sell (which creates only a contractual right in personam), a registered Sale Deed transfers ownership and risk (right in rem). In mortgages, equity prevents any 'clog on redemption' that unfairly stops a borrower from reclaiming his land after repaying the debt.",
        "keyPoints": [
          "Sale vs Agreement to Sell (Section 54): Sale transfers immediate ownership, risk, and tax liability (registration mandatory for immovable property of Rs. 100 or more); Agreement to Sell creates no present interest or charge in the property.",
          "Six Kinds of Mortgages (Section 58): (1) Simple Mortgage (personal covenant + right of court sale, no possession), (2) Mortgage by Conditional Sale (ostensible sale becoming void on repayment), (3) Usufructuary Mortgage (possession delivered; mortgagee adjusts rent/profits against debt), (4) English Mortgage (absolute transfer with proviso for retransfer on fixed date), (5) Equitable Mortgage / Deposit of Title Deeds (in notified towns, no registration needed), and (6) Anomalous Mortgage (combination of types).",
          "Mortgagor's Right of Redemption (Section 60) vs Mortgagee's Right of Foreclosure/Sale (Section 67): On paying the mortgage debt after due date, the mortgagor can reclaim property and title deeds; any term obstructing redemption is void as a 'clog on redemption.'",
          "Marshalling (Section 81) & Contribution (Section 82): Marshalling lets a subsequent mortgagee compel a prior mortgagee holding multiple properties to satisfy his debt first from non-overlapping property; Contribution distributes mortgage debt proportionately when multiple properties secure one debt.",
          "Charge (Section 100): Created by act of parties or operation of law (e.g., municipal tax arrears) making immovable property security for payment of money without transferring an interest in the property."
        ],
        "caseLaws": [
          {
            "name": "Noakes & Co. Ltd. v. Rice",
            "citation": "1902 AC 24",
            "principle": "Affirmed 'once a mortgage, always a mortgage'—any stipulation that fetters the property even after repayment of the mortgage loan is void as a clog on redemption."
          }
        ],
        "selfTest": [
          {
            "q": "Name the six kinds of mortgages under Section 58 of the Transfer of Property Act, 1882.",
            "a": "Simple Mortgage, Mortgage by Conditional Sale, Usufructuary Mortgage, English Mortgage, Mortgage by Deposit of Title Deeds (Equitable), and Anomalous Mortgage."
          }
        ],
        "visuals": []
      }
    },
    "law-of-property-u4-t1": {
      "id": "law-of-property-u4-t1",
      "subtitle": "Law of Property (TPA) - Unit 4",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "A Lease (Section 105) transfers the right to enjoy immovable property for rent/premium; a Gift (Section 122) transfers ownership voluntarily without consideration; Actionable Claims (Section 130) transfer unsecured debts; and the Indian Easements Act, 1882 governs rights of way, light, and water over another's land.",
        "legalProvision": "Sections 105-117, 122-129, and 130, Transfer of Property Act, 1882; Indian Easements Act, 1882 (Sections 4, 13, 15, and 52); Indian Succession Act, 1925",
        "meaning": "Property law distinguishes limited enjoyment (Lease and License), gratuitous transfer (Gift), intangible debt assignment (Actionable Claim), testamentary supplements (Codicil), and beneficial rights over neighbouring land (Easements).",
        "keyPoints": [
          "Lease Essentials & Termination (Sections 105-117 TPA): Requires Lessor, Lessee, immovable property, fixed/periodic duration, and rent/premium; leases from year to year or exceeding 1 year require registration (Section 107); determined under Section 111 by efflux of time, express/implied surrender, merger, forfeiture (breach/denial of title), or notice to quit.",
          "Lease vs License (Section 52, Easements Act): Lease transfers an interest in immovable property with exclusive possession (heritable and transferable); License grants a personal, revocable permission to do something on another's land without transferring any interest.",
          "Gift Essentials, Onerous Gift & Revocation (Sections 122-127 TPA): Voluntary transfer of existing property without consideration, accepted during donor's lifetime; immovable gifts require a registered, attested Gift Deed; in an Onerous Gift (Section 127), donee must accept both benefit and burden together; revocable only on agreed conditions or coercion/fraud (Section 126).",
          "Actionable Claim (Sections 3 & 130 TPA) & Codicil: An Actionable Claim is an unsecured debt or beneficial interest in movable property not in possession, transferred by a signed written instrument; a Codicil is a formal testamentary supplement explaining, altering, or adding to an existing Will.",
          "Easements (Indian Easements Act, 1882): A right attached to Dominant Heritage enjoyed over Servient Heritage (e.g., passage, light, water); acquired by Grant, Necessity (Section 13), Prescription (20 years' peaceful open enjoyment against private land; 30 years against Government land under Section 15), or Custom; extinguished by release, unity of ownership, permanent alteration, or 20 years' non-enjoyment."
        ],
        "caseLaws": [
          {
            "name": "Associated Hotels of India Ltd. v. R.N. Kapoor",
            "citation": "AIR 1959 SC 1262",
            "principle": "Laid down the decisive test distinguishing Lease from License: examine the substance and intention of the document—whether it creates an interest in property with exclusive possession (Lease) or merely personal permission (License)."
          }
        ],
        "selfTest": [
          {
            "q": "What is the statutory period for acquiring an easement by prescription under Section 15 of the Indian Easements Act, 1882?",
            "a": "20 years of peaceful, open, uninterrupted enjoyment as of right against private property, and 30 years against Government property."
          }
        ],
        "visuals": []
      }
    },
    "administrative-law-u2-t1": {
      "id": "administrative-law-u2-t1",
      "subtitle": "Administrative Law - Unit 2",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "Delegated (Subordinate) Legislation is law-making power conferred by Parliament or State Legislatures upon executive authorities to frame detailed rules, regulations, and bye-laws. Because unchecked delegation risks arbitrariness, it is strictly regulated by Legislative, Procedural, and Judicial Controls (Doctrine of Ultra Vires).",
        "legalProvision": "Article 245, Constitution of India; Doctrine of Permissible Delegation & Ultra Vires",
        "meaning": "Modern welfare governance makes delegated legislation indispensable due to parliamentary time pressure, technical complexity, local flexibility, and emergencies. However, the Legislature cannot abdicate its 'essential legislative function' (declaring legislative policy and standards).",
        "keyPoints": [
          "Reasons for Growth: Shortage of parliamentary time, highly technical subject matter (aviation, environment, finance), need for rapid adaptation to emergencies, and local flexibility.",
          "Permissible vs Impermissible Delegation: Parliament may delegate ancillary rule-making, commencement dates, or rate adjustments within clear statutory guidelines; it cannot delegate essential policy-making, unfettered taxing power, or retrospective penal laws.",
          "Legislative Control: Debates on the Parent Act, mandatory 'laying' of rules before Parliament/Assembly, and scrutiny by the Parliamentary Committee on Subordinate Legislation.",
          "Procedural Control: Prior publication of draft rules (ante-natal publicity), consultation with affected interests, and mandatory Official Gazette publication.",
          "Judicial Control (Doctrine of Ultra Vires): Courts strike down delegated legislation as Substantively Ultra Vires (violating the Constitution, exceeding Parent Act scope, or manifestly unreasonable) or Procedurally Ultra Vires (breaching mandatory consultation or publication procedures)."
        ],
        "caseLaws": [
          {
            "name": "In re Delhi Laws Act, 1912",
            "citation": "AIR 1951 SC 332",
            "principle": "Landmark 7-judge Constitution Bench decision holding that while delegated legislation is constitutionally valid in India, the Legislature cannot abdicate its essential legislative function."
          },
          {
            "name": "Hamdard Dawakhana v. Union of India",
            "citation": "AIR 1960 SC 554",
            "principle": "Struck down Section 3(d) of the Drugs and Magic Remedies Act as excessive, unguided delegation because Parliament failed to lay down clear criteria for the Executive."
          }
        ],
        "selfTest": [
          {
            "q": "What are the two limbs of the Doctrine of Ultra Vires used by courts to control delegated legislation?",
            "a": "Substantive Ultra Vires (exceeding constitutional limits or the Parent Act's authority) and Procedural Ultra Vires (failing to follow mandatory pre-publication, consultation, or Gazette notification procedures)."
          }
        ],
        "visuals": []
      }
    },
    "administrative-law-u3-t1": {
      "id": "administrative-law-u3-t1",
      "subtitle": "Administrative Law - Unit 3",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "Principles of Natural Justice ensure minimum procedural fairness in all judicial, quasi-judicial, and administrative actions with civil consequences. Its two core pillars are Nemo Judex in Causa Sua (Rule Against Bias) and Audi Alteram Partem (Right to Fair Hearing), reinforced by Reasoned Decisions (Speaking Orders).",
        "legalProvision": "Articles 14 and 21, Constitution of India; Common Law Principles of Natural Justice",
        "meaning": "Natural justice embodies fairness, impartiality, and transparency—ensuring that 'justice must not only be done, but must manifestly and undoubtedly be seen to be done.' Any order passed in violation of natural justice is void.",
        "keyPoints": [
          "Rule Against Bias (Nemo Judex in Causa Sua): No person shall be a judge in his own cause; even a 'real likelihood of bias' invalidates the decision.",
          "Three Kinds of Bias: (1) Personal Bias (friendship, family relation, or hostility with a party/lawyer), (2) Pecuniary Bias (any direct financial interest, however small), and (3) Subject-Matter / Official Bias (personal involvement or pre-judged departmental interest).",
          "Right to Fair Hearing (Audi Alteram Partem): Nobody shall be condemned unheard; includes prior clear Notice of charges, Opportunity to present evidence and rebut adverse material, Cross-examination where necessary, and 'He who hears must decide.'",
          "Reasoned Decisions (Speaking Orders): The third evolving pillar—authorities must record clear reasons for their decisions to prevent arbitrariness and enable meaningful judicial review.",
          "Exceptions to Natural Justice: Urgent emergency action, statutory exclusion, legislative/policy functions, academic evaluation, or where only one inevitable legal conclusion exists."
        ],
        "caseLaws": [
          {
            "name": "A.K. Kraipak v. Union of India",
            "citation": "AIR 1970 SC 150",
            "principle": "Quashed an IFS selection where a candidate sat on the selection board (personal bias) and held that principles of natural justice apply equally to administrative actions with civil consequences."
          },
          {
            "name": "Maneka Gandhi v. Union of India",
            "citation": "AIR 1978 SC 597",
            "principle": "Held that impounding a passport without a fair hearing violates Article 21 and Audi Alteram Partem; recognized post-decisional hearing in urgent situations."
          }
        ],
        "selfTest": [
          {
            "q": "Name the three kinds of Bias under the Rule Against Bias and the two core components of Audi Alteram Partem.",
            "a": "Personal bias, Pecuniary bias, and Subject-matter/Official bias. Core components of Audi Alteram Partem: adequate prior Notice and a fair Opportunity of Hearing."
          }
        ],
        "visuals": []
      }
    },
    "administrative-law-u4-t1": {
      "id": "administrative-law-u4-t1",
      "subtitle": "Administrative Law - Unit 4",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "Judicial and institutional checks on executive power include the Five Writs (Articles 32 & 226), Administrative Tribunals (Articles 323A-323B), State Liability in Contract (Article 299) and Tort (Article 300), Promissory Estoppel, Parliamentary oversight over Public Corporations, and anti-corruption Ombudsmen (Lokpal and Lokayukta).",
        "legalProvision": "Articles 32, 226, 299, 300, 323A, and 323B, Constitution of India; Administrative Tribunals Act, 1985; Lokpal and Lokayuktas Act, 2013",
        "meaning": "Unlike France's Droit Administratif system with separate administrative courts (Conseil d'Etat), India integrates judicial control within the Supreme Court and High Courts while using specialized Tribunals (CAT, ITAT, NCLT) and Lokpal to speed up justice and curb corruption.",
        "keyPoints": [
          "Five Constitutional Writs (Articles 32 & 226): Habeas Corpus (release from unlawful detention), Mandamus (command public official to perform legal duty), Prohibition (stop lower court/tribunal from exceeding jurisdiction), Certiorari (quash an illegal order or violation of natural justice), and Quo Warranto (challenge unauthorized usurpation of a public office).",
          "Administrative Tribunals (Articles 323A-323B): Quasi-judicial bodies (CAT, SAT, ITAT, Industrial Tribunals) providing speedy, low-cost, expert adjudication; under L. Chandra Kumar (1997), their decisions remain subject to High Court writ jurisdiction under Articles 226/227.",
          "State Liability in Contract (Article 299) & Tort (Article 300): Government contracts must be in writing, expressed in the President/Governor's name, and executed by an authorized officer; in tort, the State is vicariously liable for non-sovereign negligence (Vidyawati) and constitutional compensation for custodial violations, shrinking archaic sovereign immunity.",
          "Public Corporations & Promissory Estoppel: Statutory bodies (RBI, LIC, ONGC, Municipal Corporations) are legal persons accountable to Parliament and courts; Promissory Estoppel prevents the Government from backing out of clear lawful promises relied upon by citizens.",
          "Lokpal & Lokayukta (2013 Act): Independent statutory anti-corruption Ombudsmen at Union and State levels investigating allegations of corruption against public functionaries, alongside Commissions of Inquiry (1952 Act)."
        ],
        "caseLaws": [
          {
            "name": "State of Rajasthan v. Vidhyawati",
            "citation": "AIR 1962 SC 933",
            "principle": "Held the State vicariously liable in tort when a government jeep driver negligently killed a pedestrian while returning from a workshop—rejecting archaic 'King can do no wrong' immunity."
          },
          {
            "name": "L. Chandra Kumar v. Union of India",
            "citation": "AIR 1997 SC 1125",
            "principle": "Held that judicial review by High Courts (Articles 226/227) and Supreme Court (Article 32) over Administrative Tribunals is part of the Basic Structure and cannot be excluded."
          }
        ],
        "selfTest": [
          {
            "q": "Distinguish between the writs of Prohibition, Certiorari, and Quo Warranto.",
            "a": "Prohibition prevents a lower court/tribunal from proceeding without jurisdiction; Certiorari quashes an already passed illegal or biased order; Quo Warranto challenges a person's legal authority to hold a public office."
          }
        ],
        "visuals": []
      }
    },
    "company-law-u2-t1": {
      "id": "company-law-u2-t1",
      "subtitle": "Company Law - Unit 2",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "Promoters conceive and register a company with the Registrar of Companies (ROC) in a fiduciary capacity. Public companies raise capital through a Prospectus (with civil/criminal liability for misstatements), issuing Equity/Preference Shares (earning Dividends) and Debentures (debt instruments).",
        "legalProvision": "Sections 2(69), 7, 26, 34-35, 43, 53, 71, and 123-124, Companies Act, 2013",
        "meaning": "Company formation transforms an entrepreneurial idea into a registered corporate body upon issuance of the Certificate of Incorporation (Section 7). Strict statutory disclosures in a Prospectus protect public investors against fraud and misrepresentation.",
        "keyPoints": [
          "Promoters & Fiduciary Duties: A promoter (Section 2(69)) brings the company into existence, arranges MOA/AOA, and completes ROC registration; he stands in a fiduciary position—must not make secret profits and must disclose all personal interests.",
          "Incorporation Procedure (Section 7): Name reservation, drafting and signing MOA & AOA, filing incorporation forms/declarations with ROC, and receiving the Certificate of Incorporation with CIN.",
          "Prospectus & Remedies for Misstatement (Sections 26, 34 & 35): Any document inviting public offers for securities; untrue/misleading statements attract Rescission of allotment, Civil damages against directors/promoters (Section 35), and Criminal prosecution for fraud (Section 34 & Section 447).",
          "Kinds of Shares (Section 43) & Dividends (Sections 123-124): Equity Shares (voting rights, variable dividend) and Preference Shares (fixed priority dividend and capital repayment); Companies may also issue Bonus Shares, Rights Shares, and Sweat Equity (Section 53 bans issuing ordinary shares at a discount). Dividends are paid only out of profits; unclaimed dividend transfers to the Investor Education and Protection Fund (IEPF) after 7 years.",
          "Debentures (Section 71): Written acknowledgment of debt issued under company seal carrying fixed interest (secured/unsecured, convertible/non-convertible); debenture holders are creditors, not owners."
        ],
        "caseLaws": [
          {
            "name": "Erlanger v. New Sombrero Phosphate Co.",
            "citation": "1878 3 App Cas 1218",
            "principle": "Established that promoters stand in a fiduciary relationship to the company and cannot make secret profits without full disclosure to an independent Board."
          },
          {
            "name": "Derry v. Peek",
            "citation": "1889 14 App Cas 337",
            "principle": "Defined fraudulent misrepresentation in a prospectus (leading to statutory liability for negligent misstatements under Section 35 of the Companies Act)."
          }
        ],
        "selfTest": [
          {
            "q": "What remedies are available to an investor misled by a false statement in a company's Prospectus?",
            "a": "Rescission of the share allotment contract, civil compensation/damages from directors and promoters under Section 35, and criminal prosecution for fraud under Sections 34 and 447."
          }
        ],
        "visuals": []
      }
    },
    "company-law-u3-t1": {
      "id": "company-law-u3-t1",
      "subtitle": "Company Law - Unit 3",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "The Board of Directors (minimum 2 in private, 3 in public companies) manages company affairs under Section 179 subject to statutory fiduciary duties under Section 166. Corporate democracy operates through General Meetings (AGM, EGM, Class Meetings) and Board Meetings via Ordinary (>50%) and Special (75%) Resolutions.",
        "legalProvision": "Sections 96, 100, 103, 114, 149, 166, 169, 173, and 179, Companies Act, 2013",
        "meaning": "Because a company is an artificial person, it acts through human agents—the Board of Directors—supervised by shareholders in General Meetings and assisted by a qualified Company Secretary (KMP).",
        "keyPoints": [
          "Legal Position & Appointment of Directors: Directors act as agents and trustees of the company (not mere employees); appointed via AOA (first directors), shareholders in AGM (Section 152), Board (additional/casual vacancy), or Government/NCLT.",
          "Powers (Section 179) & Statutory Duties (Section 166): Board exercises collective powers to borrow, invest, allot shares, and approve accounts; under Section 166, directors must act in accordance with AOA, in good faith for the benefit of members, employees, and environment, with due care and no conflict of interest.",
          "Removal & Vacation of Office (Sections 167 & 169): Shareholders may remove a director before expiry by Ordinary Resolution with special notice (Section 169); office is vacated automatically upon disqualification or absence from all Board meetings for 12 months (Section 167).",
          "Kinds of Company Meetings: Annual General Meeting (AGM, Section 96—held every year with max 15-month gap and 21 clear days' notice to approve accounts, declare dividend, and appoint auditors/directors), Extraordinary General Meeting (EGM, Section 100—for urgent special business), Class Meetings, and Board Meetings (Section 173—at least 4 per year).",
          "Quorum & Resolutions (Sections 103 & 114): Valid meetings require statutory Quorum; Ordinary Resolution requires simple majority (>50% votes cast in favour), while Special Resolution (for major changes like altering MOA/AOA or winding up) requires votes cast in favour to be at least 3 times the votes against (75%)."
        ],
        "caseLaws": [
          {
            "name": "Percival v. Wright",
            "citation": "1902 2 Ch 421",
            "principle": "Held that directors owe their primary fiduciary duties to the company as a whole, rather than to individual shareholders (now codified in Section 166 of the Companies Act, 2013)."
          }
        ],
        "selfTest": [
          {
            "q": "Distinguish between an Ordinary Resolution and a Special Resolution under Section 114 of the Companies Act, 2013.",
            "a": "An Ordinary Resolution requires a simple majority (>50% of votes cast), whereas a Special Resolution requires prior notice and votes cast in favour to be at least three times (75%) the votes cast against."
          }
        ],
        "visuals": []
      }
    },
    "company-law-u4-t1": {
      "id": "company-law-u4-t1",
      "subtitle": "Company Law - Unit 4",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "Under the Rule in Foss v. Harbottle (1843), majority shareholders control internal company affairs and the company itself is the proper plaintiff. However, Sections 241-242 of the Companies Act, 2013 empower minority shareholders to seek NCLT relief against Oppression and Mismanagement, while Winding Up (Liquidation) dissolves a company's assets and legal existence.",
        "legalProvision": "Sections 241, 242, 244, 245, and 270-303, Companies Act, 2013; Insolvency and Bankruptcy Code (IBC), 2016",
        "meaning": "Company law balances majority rule with minority protection so controlling groups cannot commit fraud or freeze out minority investors. When a company becomes insolvent or fails its purpose, winding up realizes assets, pays creditors in statutory priority, and dissolves the corporate entity.",
        "keyPoints": [
          "Rule in Foss v. Harbottle (1843): Establishes two principles—(1) Proper Plaintiff Rule (only the company can sue for wrongs done to it) and (2) Majority Rule (courts do not interfere in internal irregularities ratifiable by majority).",
          "Exceptions Protecting Minority Shareholders: Minority members can sue when an act is Ultra Vires/illegal, constitutes Fraud on the Minority, requires a Special Resolution passed improperly, infringes personal membership rights, or involves Oppression and Mismanagement.",
          "Oppression & Mismanagement (Sections 241-244): Eligible minority members (100 members or 1/10th of total members, or holders of 10% issued share capital under Section 244) may petition the NCLT when affairs are conducted prejudicially to public interest, the company, or oppressive to members; NCLT can regulate conduct, buy out shares, or remove directors (Section 242).",
          "Modes of Winding Up: (1) Compulsory Winding Up by NCLT (Section 271—Special Resolution, acting against India's sovereignty/integrity, fraudulent affairs, failure to file accounts for 5 years, or just and equitable grounds) and (2) Voluntary Liquidation / Insolvency Liquidation under the Insolvency and Bankruptcy Code (IBC), 2016.",
          "Role of Company Liquidator: Takes custody of all corporate assets, recovers debts, sells property transparently, settles claims in statutory waterfall priority (secured creditors, workmen's dues, taxes, unsecured creditors, shareholders), and applies to NCLT for final dissolution."
        ],
        "caseLaws": [
          {
            "name": "Foss v. Harbottle",
            "citation": "1843 2 Hare 461",
            "principle": "Laid down the Rule of Majority Supremacy and Proper Plaintiff—minority shareholders cannot sue for internal wrongs that the majority in a general meeting can lawfully ratify, subject to recognized exceptions."
          },
          {
            "name": "Shanti Prasad Jain v. Kalinga Tubes Ltd.",
            "citation": "AIR 1965 SC 1535",
            "principle": "Explained that 'oppression' requires continuous, burdensome, harsh, and wrongful conduct showing lack of probity and fair dealing toward minority shareholders."
          }
        ],
        "selfTest": [
          {
            "q": "What is the minimum shareholder threshold to file an Oppression and Mismanagement petition before the NCLT under Section 244?",
            "a": "Not less than 100 members or 1/10th of the total number of members (whichever is less), or any member(s) holding at least 1/10th of the issued share capital."
          }
        ],
        "visuals": []
      }
    },
    "labour-law-i-u2-t1": {
      "id": "labour-law-i-u2-t1",
      "subtitle": "Labour Law - I - Unit 2",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "Under the Trade Unions Act, 1926, registration requires an application by 7+ members (with 10% or 100 workmen strength) and rule-book compliance (Sections 4-9). Registered unions maintain strict General Funds (Section 15) and optional Political Funds (Section 16), can amalgamate (Section 24), and negotiate wages and working conditions via Collective Bargaining.",
        "legalProvision": "Sections 4-11, 15, 16, 24, and 27, Trade Unions Act, 1926 (consolidated in Industrial Relations Code, 2020)",
        "meaning": "Statutory regulation of union registration, funds, amalgamation, and cancellation ensures internal democracy and prevents misuse of workers' subscriptions, while Collective Bargaining balances the unequal economic power between individual workers and employers.",
        "keyPoints": [
          "Registration Procedure (Sections 4-9): Apply to the Registrar with 7+ subscribing members (and 10% or 100 workmen engaged in the establishment), union rule book (Section 6), and office-bearer details; Registrar issues Certificate of Registration (Section 9) as conclusive proof.",
          "General Fund (Section 15) vs Political Fund (Section 16): General Fund can be spent strictly on lawful union objects (salaries, administration, trade dispute legal expenses, worker welfare/education—speculative share investments are prohibited, Mario Raposo); Political Fund is completely separate and voluntary.",
          "Amalgamation (Section 24) & Cancellation (Section 10): Two or more unions may amalgamate if at least 50% of members vote and 60% of votes cast favour it; Registrar may cancel registration for fraud/mistake, ceasing to exist, wilful contravention after notice, or dropping below minimum membership; appeal lies within 60 days (Section 11).",
          "Collective Bargaining Approaches: Distributive (traditional adversarial win-lose negotiation) and Integrative (principled win-win joint problem solving), culminating in a binding Collective Bargaining Agreement (CBA).",
          "Challenges of Indian Trade Unions: Multiplicity of unions causing inter-union rivalry, excessive politicization, outside leadership, and lack of uniform recognition rules."
        ],
        "caseLaws": [
          {
            "name": "Bokajan Cement Corporation Employees Union v. Cement Corporation of India",
            "citation": "2004 1 SCC 142",
            "principle": "Held that membership of a registered trade union does not automatically cease merely because an employee's service is terminated by the employer."
          },
          {
            "name": "Simpson & Group Companies Workers Union v. Amco Batteries Ltd.",
            "citation": "1992 Lab IC 414 (Kar)",
            "principle": "Held that physical obstruction of management officials or vehicles is not protected by Section 18 immunity; peaceful picketing is limited to oral and visual persuasion."
          }
        ],
        "selfTest": [
          {
            "q": "What voting threshold is required for amalgamating two registered Trade Unions under Section 24?",
            "a": "At least half (50%) of the members of each union must cast votes, and at least 60% of the votes recorded must be in favour of amalgamation."
          }
        ],
        "visuals": []
      }
    },
    "labour-law-i-u3-t1": {
      "id": "labour-law-i-u3-t1",
      "subtitle": "Labour Law - I - Unit 3",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "Under Section 2(j) of the Industrial Disputes Act, 1947, any systematic employer-employee activity producing goods or services satisfies the 'Triple Test' of Industry (Bangalore Water Supply). The Act creates multi-tier settlement authorities (Works Committee, Conciliation, Labour Court, Industrial Tribunal) and mandates prior Government permission for Lay-Off and Retrenchment in large establishments (Chapter V-B).",
        "legalProvision": "Sections 2(j), 3-7B, 10A, 25C, 25G, 25H, 25M, and 25N, Industrial Disputes Act, 1947",
        "meaning": "Industrial adjudication prioritizes peaceful settlement over strikes and lockouts, while Chapter V-B (applicable to factories, mines, and plantations employing 100+ workmen under the 1947 Act) prevents arbitrary mass lay-offs and retrenchments.",
        "keyPoints": [
          "Triple Test & Dominant Nature Test for 'Industry' (Section 2(j)): Systematic activity + cooperation between employer and employee + production/distribution of goods or services to satisfy human wants (profit motive is irrelevant; hospitals, universities, and municipalities are industries, while sovereign State functions are excluded).",
          "Non-Adjudicatory Authorities: Works Committee (Section 3, establishments with 100+ workers), Conciliation Officers (Section 4), Board of Conciliation (Section 5), Court of Inquiry (Section 6), and Voluntary Arbitration (Section 10A).",
          "Adjudicatory Authorities: Labour Court (Section 7—Second Schedule matters like dismissal, standing orders), Industrial Tribunal (Section 7A—Second & Third Schedule matters like wages, bonus, retrenchment), and National Tribunal (Section 7B—disputes of national importance or multi-State impact).",
          "Retrenchment Principles (Sections 25G & 25H): 'Last Come, First Go' rule requires retrenching the junior-most worker in that category first (Section 25G), and retrenched workers get statutory preference in future re-employment (Section 25H).",
          "Chapter V-B Prior Permission (Sections 25M & 25N): Large establishments (100+ workmen under ID Act) cannot lay off (Section 25M, except power shortage/natural calamity) or retrench (Section 25N, requiring 3 months' notice) without prior Government permission; permission is deemed granted if no order is communicated within 60 days."
        ],
        "caseLaws": [
          {
            "name": "Bangalore Water Supply & Sewerage Board v. A. Rajappa",
            "citation": "AIR 1978 SC 548",
            "principle": "7-judge Bench laid down the authoritative 'Triple Test' and 'Dominant Nature Test' for defining 'Industry' under Section 2(j), holding profit motive irrelevant."
          },
          {
            "name": "Santosh Gupta v. State Bank of India",
            "citation": "AIR 1980 SC 1219",
            "principle": "Held that discharge of a workman for failing a confirmation test constitutes 'retrenchment' under Section 2(oo), attracting mandatory Section 25F compliance."
          }
        ],
        "selfTest": [
          {
            "q": "What are the rules in Sections 25G and 25H of the Industrial Disputes Act regarding retrenchment?",
            "a": "Section 25G mandates the 'Last Come, First Go' principle (retrenching the junior-most worker in the category first), and Section 25H grants retrenched workers preferential right to re-employment."
          }
        ],
        "visuals": []
      }
    },
    "labour-law-i-u4-t1": {
      "id": "labour-law-i-u4-t1",
      "subtitle": "Labour Law - I - Unit 4",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "The Industrial Employment (Standing Orders) Act, 1946 requires employers to define precise service conditions and follow fair Domestic Enquiry procedures before punishment. The Factories Act, 1948 mandates comprehensive Health (Sections 11-20), Safety (Sections 21-41), Hazardous Process (Sections 41A-41H), and Welfare (Sections 42-50) standards, plus strict protections for women and young workers.",
        "legalProvision": "Industrial Employment (Standing Orders) Act, 1946; Factories Act, 1948 (Sections 2(k)-(m), 11-50, 41A-41H, and 66-77)",
        "meaning": "Standing Orders eliminate unilateral employer whim by binding both management and workers to certified workplace rules, while the Factories Act protects factory workers (10+ workers with power, or 20+ without power) against occupational hazards and child labour.",
        "keyPoints": [
          "Standing Orders Act, 1946: Requires industrial establishments (100+ workmen) to draft and get Certified Standing Orders covering classification of workmen, shifts, leave, suspension, and misconduct; Model Standing Orders apply temporarily until certification.",
          "Domestic Enquiry & Natural Justice: Before punishing a workman for misconduct, management must issue a clear Charge Sheet, allow a written Explanation, appoint an impartial Enquiry Officer, permit cross-examination, supply the Enquiry Report, and impose proportionate punishment.",
          "Factories Act Definitions (Sections 2(k), 2(l), 2(m)): 'Factory' covers premises with 10+ workers using power or 20+ without power engaged in a 'Manufacturing Process' (includes bidi making and salt making); excludes mines, hotels, and railway running sheds.",
          "Health, Safety & Welfare Provisions: Health (Sections 11-20—cleanliness, ventilation, dust/fumes, drinking water 6m from latrines, overcrowding limits), Safety (Sections 21-41—mandatory fencing of machinery, eye protection, hazardous process disclosure under Sections 41A-41H), and Welfare (Sections 42-50—washing, first aid, canteen for 250+ workers, creche for 30+ women, Welfare Officer for 500+ workers).",
          "Protection of Women & Young Persons (Sections 66-77): Prohibits employing children below 14 years (Section 67), requires medical fitness certificates for adolescents (Sections 68-69), restricts women from night work between 7 PM and 6 AM (Section 66), and bars women/children near cotton openers (Section 27)."
        ],
        "caseLaws": [
          {
            "name": "State of Gujarat v. Jethalal Ghelabhai Patel",
            "citation": "AIR 1964 SC 779",
            "principle": "Held under Section 21 of the Factories Act that an occupier's duty to fence dangerous machinery is absolute; claiming someone removed the guard without knowledge is no defence."
          },
          {
            "name": "Managing Director, ECIL v. B. Karunakar",
            "citation": "AIR 1994 SC 1074",
            "principle": "Held that supplying a copy of the Domestic Enquiry Officer's report to the delinquent employee before imposing punishment is an essential component of natural justice."
          }
        ],
        "selfTest": [
          {
            "q": "What are the threshold worker counts defining a 'Factory' under Section 2(m) of the Factories Act, 1948, and what is the minimum age to work in a factory?",
            "a": "10 or more workers with the aid of power, or 20 or more workers without power; Section 67 strictly prohibits employing any child under 14 years of age."
          }
        ],
        "visuals": []
      }
    }
  }
}
'@

$packPath = Join-Path $dataDir "sem3_batch2_units2to4_pack.json"
[System.IO.File]::WriteAllText($packPath, $sem3B2Json, $u)

Write-Host "`n=== 1. Merging Semester 3 Batch 2 (Units 2-4) into www/nyayasaral_db.json (Zero Overlap) ===" -ForegroundColor Cyan
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

print(f"[PASS] Merged Semester 3 Batch 2 (Units 2-4): +{added_subjs} subjects, +{added_topics} English topics (Total topics now: {len(notes)})")
'@

$tmpPy = Join-Path $env:TEMP "ls_merge_sem3_b2.py"
[System.IO.File]::WriteAllText($tmpPy, $pyMerge, $u)
python -u $tmpPy (Join-Path $root "www\nyayasaral_db.json") $packPath
if ($LASTEXITCODE -ne 0) { throw "Merge failed!" }

if ($PushOta) {
  Write-Host "`n=== 2. Running Built-In EN -> TE/HI Auto-Converter & Deploying Live OTA ===" -ForegroundColor Cyan
  & (Join-Path $root "Push-LawStudyes-OTA.ps1") -Message "Added Sem 3 Units 2-4 (15 Hand-Crafted Topics across Jurisprudence, Property, Admin Law, Company Law, Labour Law I) + Auto TE/HI"
}