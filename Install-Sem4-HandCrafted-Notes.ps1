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

$sem4Json = @'
{
  "subjects": [
    {
      "id": "labour-law-ii",
      "title": "Labour Law - II",
      "semester": "Semester 4",
      "url": "",
      "units": [
        {
          "unitNo": 1,
          "title": "Wages, Payment of Wages & Minimum Wages",
          "topics": [
            {"id": "labour-law-ii-u1-t1", "title": "1. Concept of Wages (Minimum, Fair & Living Wage) & Payment of Wages Act, 1936"}
          ]
        },
        {
          "unitNo": 2,
          "title": "Social Security - Employee's Compensation & ESI Act",
          "topics": [
            {"id": "labour-law-ii-u2-t1", "title": "1. Employee's Compensation Act, 1923 & ESI Act, 1948 - Liability, Notional Extension & Benefits"}
          ]
        }
      ]
    },
    {
      "id": "public-international-law",
      "title": "Public International Law",
      "semester": "Semester 4",
      "url": "",
      "units": [
        {
          "unitNo": 1,
          "title": "Nature, Definitions & Sources of International Law",
          "topics": [
            {"id": "public-international-law-u1-t1", "title": "1. International Law - Definition, Nature & Modern Sources (Article 38 ICJ Statute)"}
          ]
        },
        {
          "unitNo": 2,
          "title": "Recognition of States & State Succession",
          "topics": [
            {"id": "public-international-law-u2-t1", "title": "1. Recognition of States - Theories, De Facto vs De Jure & Legal Effects"}
          ]
        }
      ]
    },
    {
      "id": "interpretation-of-statutes",
      "title": "Interpretation of Statutes",
      "semester": "Semester 4",
      "url": "",
      "units": [
        {
          "unitNo": 1,
          "title": "Meaning, Need & Interpretation vs Construction",
          "topics": [
            {"id": "interpretation-of-statutes-u1-t1", "title": "1. Interpretation of Statutes - Meaning, Need & Distinction from Construction"}
          ]
        },
        {
          "unitNo": 2,
          "title": "Primary Rules of Statutory Interpretation",
          "topics": [
            {"id": "interpretation-of-statutes-u2-t1", "title": "1. Primary Rules - Literal (Grammatical), Golden & Mischief Rules (Heydon's Case)"}
          ]
        }
      ]
    },
    {
      "id": "land-laws",
      "title": "Land Laws",
      "semester": "Semester 4",
      "url": "",
      "units": [
        {
          "unitNo": 1,
          "title": "Constitutional Doctrines - Eminent Domain, Escheat & Bona Vacantia",
          "topics": [
            {"id": "land-laws-u1-t1", "title": "1. Doctrine of Eminent Domain, Escheat & Bona Vacantia (Article 300A)"}
          ]
        },
        {
          "unitNo": 2,
          "title": "Land Reforms, Ceiling Laws & Record of Rights",
          "topics": [
            {"id": "land-laws-u2-t1", "title": "1. Pre- and Post-Independence Land Reforms, Land Ceiling & Record of Rights (ROR)"}
          ]
        }
      ]
    },
    {
      "id": "intellectual-property-law",
      "title": "Intellectual Property Law",
      "semester": "Semester 4",
      "url": "",
      "units": [
        {
          "unitNo": 1,
          "title": "Nature & Forms of Intellectual Property Rights",
          "topics": [
            {"id": "intellectual-property-law-u1-t1", "title": "1. Intellectual Property Rights - Meaning, Characteristics & Main Forms (Patents, Copyright, Trademarks, Designs & GI)"}
          ]
        },
        {
          "unitNo": 2,
          "title": "International IPR Framework - WIPO, WTO & TRIPS",
          "topics": [
            {"id": "intellectual-property-law-u2-t1", "title": "1. TRIPS Agreement, WIPO & WTO - Global Standards & Impact on Indian IP Law"}
          ]
        }
      ]
    }
  ],
  "notes": {
    "labour-law-ii-u1-t1": {
      "id": "labour-law-ii-u1-t1",
      "subtitle": "Labour Law - II - Unit 1",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "Indian labour jurisprudence classifies wages into Minimum Wage (irreducible floor for basic survival), Fair Wage (above minimum, linked to industry capacity), and Living Wage (constitutional goal under Article 43). The Payment of Wages Act, 1936 ensures timely payment and prevents arbitrary deductions, while the Minimum Wages Act, 1948 prevents sweated labour.",
        "legalProvision": "Article 43, Constitution of India; Payment of Wages Act, 1936 (Sections 5 & 7); Minimum Wages Act, 1948 (Sections 11 & 25) (now consolidated in the Code on Wages, 2019)",
        "meaning": "Based on the Whitley Commission (Royal Commission on Labour, 1929-31) recommendations, wage legislation protects workers from delayed payments, unauthorized deductions, and exploitation. Any contract by which a worker agrees to accept less than the statutory minimum wage is null and void under Section 25 of the Minimum Wages Act, 1948.",
        "keyPoints": [
          "Minimum Wage: An irreducible floor sufficient for bare subsistence (food, clothing, shelter, plus basic education and medical needs) payable regardless of the employer's capacity to pay.",
          "Fair Wage: Lies between the minimum wage (lower limit) and living wage (upper limit), determined by industry-cum-region capacity to pay.",
          "Living Wage (Article 43): The highest standard enabling a worker to maintain a frugal comfort, education, healthcare, and social security against old age.",
          "Timely Payment (Section 5, Payment of Wages Act, 1936): Establishments with fewer than 1,000 employees must pay wages before the 7th day of the following month; establishments with 1,000 or more must pay before the 10th day.",
          "Authorized Deductions (Section 7, Payment of Wages Act, 1936): Only specified deductions (fines, absence from duty, damage/loss due to neglect under Section 7(2)(c), house accommodation, income tax, PF) are permitted.",
          "Contracting Out Void (Section 25, Minimum Wages Act, 1948): Any agreement relinquishing or reducing the right to minimum wages is null and void."
        ],
        "caseLaws": [
          {
            "name": "Express Newspaper (P) Ltd. v. Union of India",
            "citation": "AIR 1958 SC 578",
            "principle": "Distinguished Minimum Wage, Fair Wage, and Living Wage, holding that an industry unable to pay even the bare minimum wage has no right to exist."
          },
          {
            "name": "People's Union for Democratic Rights v. Union of India (Asiad Workers Case)",
            "citation": "AIR 1982 SC 1473",
            "principle": "Held that paying less than the statutory minimum wage amounts to 'forced labour' prohibited under Article 23 of the Constitution."
          }
        ],
        "selfTest": [
          {
            "q": "What is the time limit for paying wages under Section 5 of the Payment of Wages Act, 1936?",
            "a": "Before the expiry of the 7th day after the wage period if fewer than 1,000 workers are employed, and before the 10th day if 1,000 or more workers are employed."
          }
        ],
        "visuals": []
      }
    },
    "labour-law-ii-u2-t1": {
      "id": "labour-law-ii-u2-t1",
      "subtitle": "Labour Law - II - Unit 2",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "Under the Employee's Compensation Act, 1923, an employer must compensate an employee for personal injury or occupational disease caused by an accident 'arising out of and in the course of employment.' The ESI Act, 1948 provides comprehensive contributory social insurance covering medical, sickness, maternity, disablement, and dependants' benefits.",
        "legalProvision": "Section 3, Employee's Compensation Act, 1923; Employees' State Insurance Act, 1948 (Sections 3 & 46) (now consolidated in the Social Security Code, 2020)",
        "meaning": "Social security laws shift the financial risk of workplace accidents and illness from vulnerable workers to employers or statutory insurance funds. Under Section 53 of the ESI Act, an employee covered by ESI cannot claim dual compensation under the 1923 Act.",
        "keyPoints": [
          "Employer's Liability (Section 3, 1923 Act): Triggered when personal injury or scheduled occupational disease arises 'out of' (causal nexus) and 'in the course of' (time and place) employment.",
          "Doctrine of Notional Extension: Extends employment beyond actual factory premises to include reasonable travel to and from duty when using employer-provided transport or facing employment-linked hazards.",
          "Employer's Defences: Employer is not liable for non-fatal injuries caused by the employee's intoxication, wilful disobedience of safety rules, or wilful removal of safety guards.",
          "Types of Disablement: Partial Disablement (temporary or permanent reduction in earning capacity) and Total Disablement (incapacity for all work the employee was capable of performing).",
          "ESI Act, 1948 Authorities & Benefits: Administered by the ESI Corporation, Standing Committee, and Medical Benefit Council; provides six core benefits—Medical, Sickness, Maternity, Disablement, Dependants', and Funeral expenses."
        ],
        "caseLaws": [
          {
            "name": "Saurashtra Salt Manufacturing Co. v. Bai Valu Raja",
            "citation": "AIR 1958 SC 881",
            "principle": "Explained the Doctrine of Notional Extension of employment, clarifying when accidents during commuting fall within 'in the course of employment'."
          },
          {
            "name": "Superintending Engineer, T.N.S.E.B. v. Sankupathy",
            "citation": "2004 (5) CTC 321",
            "principle": "Applied the Doctrine of Notional Extension to award compensation where an employee met with a fatal accident while proceeding to duty."
          }
        ],
        "selfTest": [
          {
            "q": "What is the Doctrine of Notional Extension under the Employee's Compensation Act, 1923?",
            "a": "It is a judicial doctrine extending the scope of 'course of employment' beyond the actual workplace premises to cover reasonable commuting or employer-provided transport linked to duty."
          }
        ],
        "visuals": []
      }
    },
    "public-international-law-u1-t1": {
      "id": "public-international-law-u1-t1",
      "subtitle": "Public International Law - Unit 1",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "Public International Law (coined by Jeremy Bentham; Hugo Grotius is its Father) is the body of customary, treaty, and general legal rules governing relations between sovereign States, international organizations, and individuals. Its authoritative sources are listed in Article 38(1) of the Statute of the International Court of Justice (ICJ).",
        "legalProvision": "Article 38(1), Statute of the International Court of Justice (ICJ); Charter of the United Nations, 1945",
        "meaning": "Unlike Private International Law (conflict of laws governing cross-border private disputes), Public International Law regulates inter-State conduct, treaties, diplomatic immunity, human rights, and international institutions such as the UN and ICJ.",
        "keyPoints": [
          "Classical vs Modern Definitions: Oppenheim defined it as customary and treaty rules binding civilized States; Starke expanded it to include international organizations (UN, WHO, ILO) and individuals (human rights, international crimes).",
          "Primary Sources (Article 38(1)(a)-(c) ICJ Statute): (1) International Conventions/Treaties (law-making and bilateral treaties), (2) International Custom (consistent State practice plus opinio juris), and (3) General Principles of Law recognized by civilized nations (e.g., Res Judicata, good faith, estoppel).",
          "Subsidiary Sources (Article 38(1)(d)): Judicial decisions of the ICJ and international tribunals, and teachings of highly qualified publicists (jurists).",
          "Modern Sources: Resolutions and declarations of the UN General Assembly (e.g., Universal Declaration of Human Rights, 1948) and specialized agencies.",
          "Binding Basis: Rooted in the consent of the international community (Pacta Sunt Servanda—treaties must be observed in good faith)."
        ],
        "caseLaws": [
          {
            "name": "The Paquete Habana",
            "citation": "1900 175 US 677",
            "principle": "Held that established international custom (exempting coastal fishing vessels from capture in war) is binding law even without a formal treaty."
          },
          {
            "name": "North Sea Continental Shelf Cases",
            "citation": "1969 ICJ Rep 3",
            "principle": "Clarified that international custom requires two elements: widespread State practice and opinio juris (belief that the practice is legally obligatory)."
          }
        ],
        "selfTest": [
          {
            "q": "What are the four sources of International Law enumerated in Article 38(1) of the ICJ Statute?",
            "a": "International conventions (treaties), international custom, general principles of law recognized by civilized nations, and judicial decisions/writings of eminent jurists as subsidiary means."
          }
        ],
        "visuals": []
      }
    },
    "public-international-law-u2-t1": {
      "id": "public-international-law-u2-t1",
      "subtitle": "Public International Law - Unit 2",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "Recognition is the formal acknowledgment by existing States that a new political entity possesses statehood or that a new government effectively controls a State. The two main theories are Constitutive and Declaratory, and recognition may be De Facto (provisional) or De Jure (final and permanent).",
        "legalProvision": "Article 1, Montevideo Convention on the Rights and Duties of States, 1933; Customary International Law",
        "meaning": "Recognition enables a newly emerged State or government to enter diplomatic relations, sign treaties, sue in foreign courts, and claim sovereign immunity. There is no strict legal duty to recognize a new State, as recognition remains a political act with major legal consequences.",
        "keyPoints": [
          "Constitutive Theory (Oppenheim, Hegel): A new State acquires international legal personality only through recognition by existing States.",
          "Declaratory Theory (Hall, Brierly): Statehood exists as a matter of fact once Montevideo criteria (population, territory, government, capacity to enter relations) are met; recognition merely declares an existing fact.",
          "De Facto Recognition: Provisional and conditional recognition granted when a new government has effective control but lacks full permanence; revocable and does not confer full diplomatic immunities.",
          "De Jure Recognition: Final, unconditional, and irrevocable recognition confirming legal and permanent stability; grants full diplomatic relations and sovereign immunity.",
          "Modes & Legal Effects: May be Express (formal declaration/treaty) or Implied (entering bilateral treaties or exchanging diplomats); operates retrospectively from the date the new State/government came into existence."
        ],
        "caseLaws": [
          {
            "name": "Luther v. Sagor",
            "citation": "1921 3 KB 532",
            "principle": "Held that once the British Government granted De Facto recognition to the Soviet Government, its legislative acts were validated retrospectively by English courts."
          }
        ],
        "selfTest": [
          {
            "q": "Distinguish between De Facto and De Jure recognition in International Law.",
            "a": "De Facto recognition is provisional and revocable based on actual control, whereas De Jure recognition is final, permanent, irrevocable, and confers full diplomatic status."
          }
        ],
        "visuals": []
      }
    },
    "interpretation-of-statutes-u1-t1": {
      "id": "interpretation-of-statutes-u1-t1",
      "subtitle": "Interpretation of Statutes - Unit 1",
      "readTime": "4 min read",
      "url": "",
      "en": {
        "inOneMinute": "A Statute is the formal written will of the Legislature (Maxwell). Interpretation is the judicial process of ascertaining the true meaning of statutory words, while Construction draws legal conclusions from the spirit of the statute when the literal text is ambiguous or incomplete.",
        "legalProvision": "General Clauses Act, 1897; Article 367, Constitution of India",
        "meaning": "When the Legislature's task of enacting a law ends, the Judiciary's duty of interpreting it begins. Because human language is imperfect and statutes must apply to evolving real-world facts, courts use established rules of interpretation and construction to give effect to legislative intent.",
        "keyPoints": [
          "Meaning of Statute: Written law enacted by a competent legislature (Parliament or State Legislature) receiving Presidential or Gubernatorial assent.",
          "Definitions: Salmond defines interpretation as the process by which courts ascertain the meaning of the legislature through authoritative statutory forms; Cross defines it as determining statutory meaning to apply it to facts before the court.",
          "Need for Interpretation: Required due to ambiguity of words, drafting omissions, unforeseen social/technological developments, and overlapping statutory provisions.",
          "Interpretation vs Construction: Interpretation finds the true sense of the words used in the text; Construction goes beyond the literal text to draw conclusions within the spirit of the law (e.g., beneficial construction for labour laws, harmonious construction to avoid conflict).",
          "Classification of Statutes: Codifying, Consolidating, Declaratory, Remedial/Welfare (interpreted liberally), Penal and Taxing statutes (interpreted strictly)."
        ],
        "caseLaws": [
          {
            "name": "Seaford Court Estates Ltd. v. Asher",
            "citation": "1949 2 KB 481",
            "principle": "Lord Denning famously observed that when a defect appears in a statute, a judge cannot simply fold his hands and blame the draftsman, but must iron out the creases to fulfil Parliament's intention."
          }
        ],
        "selfTest": [
          {
            "q": "How does Construction differ from Interpretation of a statute?",
            "a": "Interpretation ascertains the true linguistic meaning of the statutory text, whereas Construction draws legal conclusions from the spirit and object of the statute where the text alone is insufficient."
          }
        ],
        "visuals": []
      }
    },
    "interpretation-of-statutes-u2-t1": {
      "id": "interpretation-of-statutes-u2-t1",
      "subtitle": "Interpretation of Statutes - Unit 2",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "Courts apply three primary rules of statutory interpretation: the Literal (Grammatical) Rule gives words their plain ordinary meaning; the Golden Rule modifies literal meaning to avoid absurdity; and the Mischief Rule (Heydon's Case) interprets the law to suppress the mischief and advance the remedy.",
        "legalProvision": "Common Law Canons of Construction applied by Indian Courts; General Clauses Act, 1897",
        "meaning": "The primary rules guide judges in moving logically from the plain text of a statute to its underlying legislative purpose whenever literal reading creates ambiguity, absurdity, or defeats the reform Parliament intended.",
        "keyPoints": [
          "Literal (Grammatical) Rule: The first and safest rule—words must be given their plain, ordinary, and natural grammatical meaning without adding or subtracting words when the text is clear and unambiguous.",
          "Golden Rule: Allows a court to depart from the strict literal meaning to the extent necessary to avoid manifest absurdity, repugnancy, or inconsistency with the rest of the statute.",
          "Mischief Rule (Heydon's Case, 1584): Directs courts to examine four factors: (1) What was the common law before the Act? (2) What was the mischief/defect not provided for? (3) What remedy did Parliament resolve? (4) What is the true reason of the remedy?—then suppress the mischief and advance the remedy.",
          "Harmonious Construction: When two provisions of the same statute appear to conflict, courts must interpret both so as to give effect to each without rendering either redundant.",
          "Strict vs Beneficial Construction: Penal and taxing statutes are construed strictly in favour of the citizen, whereas social welfare and labour statutes are construed beneficially to advance worker protection."
        ],
        "caseLaws": [
          {
            "name": "Heydon's Case",
            "citation": "1584 3 Co Rep 7a",
            "principle": "Formulated the four-part Mischief Rule, instructing judges to interpret statutes to suppress the mischief and advance the legislative remedy."
          },
          {
            "name": "Bengal Immunity Co. Ltd. v. State of Bihar",
            "citation": "AIR 1955 SC 661",
            "principle": "Applied the Mischief Rule in India to interpret Article 286 of the Constitution and prevent multiple inter-State sales taxation."
          }
        ],
        "selfTest": [
          {
            "q": "What are the four questions asked by a court under the Mischief Rule in Heydon's Case?",
            "a": "The prior common law, the mischief/defect in that law, the remedy enacted by the legislature, and the true reason for that remedy."
          }
        ],
        "visuals": []
      }
    },
    "land-laws-u1-t1": {
      "id": "land-laws-u1-t1",
      "subtitle": "Land Laws - Unit 1",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "Eminent Domain is the sovereign power of the State to acquire private property for a public purpose upon paying just compensation, subject to Article 300A. Under Escheat, ownerless property of a person dying without heirs vests in the State, while Bona Vacantia vests unclaimed or vacant property in the State.",
        "legalProvision": "Articles 296 and 300A, Constitution of India (44th Amendment Act, 1978); Right to Fair Compensation and Transparency in Land Acquisition, Rehabilitation and Resettlement Act, 2013 (replacing 1894 Act)",
        "meaning": "Rooted in the maxims 'Salus Populi Est Suprema Lex' (public welfare is the supreme law) and 'Necessitas Publica Major Est Quam Privata' (public necessity outweighs private interest), these three doctrines define the State's ultimate authority over land and ownerless property.",
        "keyPoints": [
          "Doctrine of Eminent Domain: Inherent sovereign power to compulsorily acquire private land (for railways, dams, highways, universities) without the owner's consent, subject to two strict safeguards—Public Purpose and Just Compensation.",
          "44th Constitutional Amendment (1978): Repealed Articles 19(1)(f) and 31 (Right to Property as a Fundamental Right) and inserted Article 300A—no person shall be deprived of property save by authority of law.",
          "Eminent Domain vs Taxation & Police Power: Eminent domain targets specific individual property for public use with compensation; taxation and police power apply uniformly across classes without direct compensation.",
          "Doctrine of Escheat (Article 296 & Section 29, Hindu Succession Act, 1956): When a person dies intestate without leaving any legal heirs, his property devolves upon the State.",
          "Doctrine of Bona Vacantia (Article 296): Unclaimed, abandoned, or ownerless property (such as unclaimed bank deposits, dissolved company assets, or unowned lands/forests) vests in the State."
        ],
        "caseLaws": [
          {
            "name": "State of West Bengal v. Union of India",
            "citation": "AIR 1963 SC 1241",
            "principle": "Defined Eminent Domain as the sovereign power to take private property for public use without the owner's consent upon making just compensation."
          },
          {
            "name": "K.T. Plantation Pvt. Ltd. v. State of Karnataka",
            "citation": "2011 9 SCC 1",
            "principle": "Affirmed that even under Article 300A, public purpose and compensation are implicit constitutional requirements for valid State acquisition of private property."
          }
        ],
        "selfTest": [
          {
            "q": "What are the two mandatory constitutional safeguards on the State's exercise of Eminent Domain?",
            "a": "The acquisition must be backed by authority of law for a genuine public purpose, and the owner must be paid just compensation."
          }
        ],
        "visuals": []
      }
    },
    "land-laws-u2-t1": {
      "id": "land-laws-u2-t1",
      "subtitle": "Land Laws - Unit 2",
      "readTime": "4 min read",
      "url": "",
      "en": {
        "inOneMinute": "Post-independence Indian land reforms abolished Zamindari intermediaries, protected agricultural tenants, imposed land-holding ceilings to redistribute surplus land to the landless, and established transparent Record of Rights (ROR / Pahani / Pattadar Passbooks).",
        "legalProvision": "Articles 38, 39(b)-(c), and 31B (Ninth Schedule), Constitution of India; State Land Ceiling & Record of Rights (ROR) Acts",
        "meaning": "Before independence, colonial revenue systems (Zamindari, Ryotwari, Mahalwari) concentrated land in feudal intermediaries and exploited cultivators. Independent India enacted agrarian reforms to achieve distributive justice and give 'land to the tiller.'",
        "keyPoints": [
          "Pre-Independence Systems: Zamindari (intermediary landlords collecting revenue), Mahalwari (village-level revenue collection), and Ryotwari (direct settlement with cultivators), alongside the colonial Land Acquisition Act, 1894.",
          "Abolition of Intermediaries: Eliminated Zamindars, Jagirdars, and Inamdars, bringing cultivators into direct relationship with the State.",
          "Tenancy Reforms: Granted security of tenure, regulated fair rent, and conferred ownership rights on cultivating tenants.",
          "Agricultural Land Ceiling Laws: Fixed a maximum ceiling on agricultural land holdings; surplus land above the ceiling was acquired by the State and redistributed to landless poor.",
          "Survey & Record of Rights (ROR): Systematic land surveys assigned survey numbers; revenue authorities (Tahsildar/Collector) maintain village Pahani/Adangal records and issue Pattadar Passbooks as proof of title and possession."
        ],
        "caseLaws": [
          {
            "name": "I.R. Coelho v. State of Tamil Nadu",
            "citation": "AIR 2007 SC 861",
            "principle": "Held that land reform laws placed in the Ninth Schedule after 24 April 1973 are still open to judicial review if they violate the Basic Structure of the Constitution."
          }
        ],
        "selfTest": [
          {
            "q": "What were the four major pillars of post-independence land reforms in India?",
            "a": "Abolition of intermediaries (Zamindari), tenancy reforms, imposition of agricultural land ceilings with redistribution, and maintenance of updated Record of Rights (ROR)."
          }
        ],
        "visuals": []
      }
    },
    "intellectual-property-law-u1-t1": {
      "id": "intellectual-property-law-u1-t1",
      "subtitle": "Intellectual Property Law - Unit 1",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "Intellectual Property (IP) refers to intangible creations of the human intellect—such as inventions, literary/artistic works, brand names, industrial designs, and geographical indications—protected by statutory monopoly rights for limited periods before entering the public domain.",
        "legalProvision": "Patents Act, 1970; Copyright Act, 1957; Trade Marks Act, 1999; Designs Act, 2000; Geographical Indications of Goods Act, 1999",
        "meaning": "IPR grants creators exclusive commercial rights (use, licensing for royalty, assignment, and suing for infringement) to incentivize innovation and creativity while balancing public access once the statutory term expires.",
        "keyPoints": [
          "Patents (Patents Act, 1970): Protects new, non-obvious, industrially applicable inventions (products or processes) for 20 years from filing; requires novelty, inventive step, and industrial utility.",
          "Copyright (Copyright Act, 1957): Protects original literary, dramatic, musical, artistic works, cinematograph films, and sound recordings (generally author's lifetime + 60 years in India); exists automatically upon creation.",
          "Trademarks (Trade Marks Act, 1999): Protects distinctive brand names, logos, symbols, and packaging that distinguish one trader's goods/services from others; renewable every 10 years indefinitely.",
          "Industrial Designs (Designs Act, 2000): Protects the visual aesthetic features (shape, configuration, pattern, ornament) applied to an article for up to 15 years.",
          "Geographical Indications (GI Act, 1999): Identifies goods originating from a specific region with unique qualities or reputation (e.g., Darjeeling Tea, Pochampally Ikat, Tirupati Laddu, Hyderabadi Haleem).",
          "Core Characteristics: Intangible/incorporeal right, territorial in nature, statutory and time-bound (except trademarks/GIs), transferable via assignment or licensing."
        ],
        "caseLaws": [
          {
            "name": "Novartis AG v. Union of India",
            "citation": "2013 6 SCC 1",
            "principle": "Upheld Section 3(d) of the Patents Act, 1970 to prevent 'evergreening' of pharmaceutical patents where a modified form shows no enhanced therapeutic efficacy."
          }
        ],
        "selfTest": [
          {
            "q": "What are the five primary forms of Intellectual Property protected by Indian statutes?",
            "a": "Patents (1970 Act), Copyrights (1957 Act), Trademarks (1999 Act), Industrial Designs (2000 Act), and Geographical Indications (1999 Act)."
          }
        ],
        "visuals": []
      }
    },
    "intellectual-property-law-u2-t1": {
      "id": "intellectual-property-law-u2-t1",
      "subtitle": "Intellectual Property Law - Unit 2",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "The TRIPS Agreement (1994), administered by the World Trade Organization (WTO), establishes binding minimum global standards for protecting and enforcing Intellectual Property Rights, complementing the World Intellectual Property Organization (WIPO) established in 1967.",
        "legalProvision": "TRIPS Agreement (1994, Annex 1C of WTO Agreement); Stockholm Convention establishing WIPO (1967); Doha Declaration on TRIPS and Public Health (2001)",
        "meaning": "Because intellectual property piracy and technology transfer cross national borders, TRIPS harmonizes minimum IP standards across WTO member countries while preserving public-health flexibilities such as compulsory licensing.",
        "keyPoints": [
          "WIPO (Established 1967, Stockholm): A specialized UN agency promoting global IP protection and administering key treaties like the Paris Convention (industrial property) and Berne Convention (copyright).",
          "TRIPS Agreement (1994): Most comprehensive multilateral IP treaty under the WTO; binds all member States to minimum standards across Copyright, Trademarks, GIs, Designs, Patents, and Trade Secrets.",
          "Core TRIPS Principles: National Treatment (treating foreign IP owners no less favourably than domestic citizens) and Most-Favoured-Nation (MFN) Treatment.",
          "Patent Standards & Public Health Flexibilities: Mandates 20-year product and process patents across all fields of technology, while permitting exclusions for public order/morality and Compulsory Licensing during public health crises (reaffirmed by the Doha Declaration, 2001).",
          "Impact on India: Led India to amend the Patents Act (introducing product patents in pharmaceuticals in 2005 with Section 3(d) anti-evergreening safeguards) and enact the Trade Marks Act, 1999, GI Act, 1999, and Designs Act, 2000."
        ],
        "caseLaws": [
          {
            "name": "Bayer Corporation v. Natco Pharma Ltd.",
            "citation": "2014 (60) PTC 277 (Bom)",
            "principle": "Upheld India's first Compulsory Licence under Section 84 of the Patents Act (compliant with TRIPS flexibilities) for the cancer drug Nexavar to ensure affordable public access."
          }
        ],
        "selfTest": [
          {
            "q": "How does the TRIPS Agreement balance global patent protection with public health in developing countries?",
            "a": "While mandating 20-year product patents, TRIPS and the Doha Declaration (2001) allow countries to grant Compulsory Licences and prevent patent evergreening to protect affordable access to medicines."
          }
        ],
        "visuals": []
      }
    }
  }
}
'@

$packPath = Join-Path $dataDir "sem4_handcrafted_pack.json"
[System.IO.File]::WriteAllText($packPath, $sem4Json, $u)

Write-Host "`n=== 1. Merging Hand-Crafted Semester 4 Pack into www/nyayasaral_db.json (Zero Overlap) ===" -ForegroundColor Cyan
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

print(f"[PASS] Merged Semester 4 Hand-Crafted Notes: +{added_subjs} subjects, +{added_topics} English topics (Total topics now: {len(notes)})")
'@

$tmpPy = Join-Path $env:TEMP "ls_merge_sem4.py"
[System.IO.File]::WriteAllText($tmpPy, $pyMerge, $u)
python -u $tmpPy (Join-Path $root "www\nyayasaral_db.json") $packPath
if ($LASTEXITCODE -ne 0) { throw "Merge failed!" }

if ($PushOta) {
  Write-Host "`n=== 2. Running Built-In EN -> TE/HI Auto-Converter & Deploying Live OTA ===" -ForegroundColor Cyan
  & (Join-Path $root "Push-LawStudyes-OTA.ps1") -Message "Added Hand-Crafted Semester 4 Subjects (Labour Law II, Public International Law, Interpretation of Statutes, Land Laws, IPR) + Auto TE/HI"
}