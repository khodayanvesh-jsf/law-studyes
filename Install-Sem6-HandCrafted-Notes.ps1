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

$sem6Json = @'
{
  "subjects": [
    {
      "id": "law-of-taxation",
      "title": "Law of Taxation (Income Tax & GST)",
      "semester": "Semester 6",
      "url": "",
      "units": [
        {
          "unitNo": 1,
          "title": "Constitutional Basis & Income Tax Act, 1961",
          "topics": [
            {"id": "law-of-taxation-u1-t1", "title": "1. Constitutional Basis (Article 265), Direct vs Indirect Tax, Residential Status & Five Heads of Income"}
          ]
        },
        {
          "unitNo": 2,
          "title": "GST Act, 2017 & Tax Procedure (PAN, TDS & Double Tax Relief)",
          "topics": [
            {"id": "law-of-taxation-u2-t1", "title": "1. Goods and Services Tax (GST) Act, 2017 - CGST/SGST/IGST, Input Tax Credit & Composite vs Mixed Supply"}
          ]
        }
      ]
    },
    {
      "id": "information-technology-law",
      "title": "Information Technology & Cyber Law",
      "semester": "Semester 6",
      "url": "",
      "units": [
        {
          "unitNo": 1,
          "title": "Cyberspace, Jurisdiction & IT Act, 2000",
          "topics": [
            {"id": "information-technology-law-u1-t1", "title": "1. Cyberspace, Internet Jurisdiction, E-Governance, Digital Signatures & Intermediary Liability"}
          ]
        },
        {
          "unitNo": 2,
          "title": "Cyber Crimes, Data Privacy & E-Commerce",
          "topics": [
            {"id": "information-technology-law-u2-t1", "title": "1. Cyber Crimes under IT Act, 2000 (Hacking, Phishing, Cyber Stalking, Identity Theft) & Data Privacy"}
          ]
        }
      ]
    },
    {
      "id": "law-relating-to-women",
      "title": "Law Relating to Women",
      "semester": "Semester 6",
      "url": "",
      "units": [
        {
          "unitNo": 1,
          "title": "Constitutional Gender Justice, UCC & Property Rights",
          "topics": [
            {"id": "law-relating-to-women-u1-t1", "title": "1. Status of Women, Constitutional Safeguards for Gender Justice, Uniform Civil Code (Art. 44) & Equal Property Rights"}
          ]
        },
        {
          "unitNo": 2,
          "title": "Protective Statutes & International Instruments (CEDAW)",
          "topics": [
            {"id": "law-relating-to-women-u2-t1", "title": "1. Dowry Prohibition, Domestic Violence, POSH Act, MTP/PCPNDT Acts, Maternity Benefit & CEDAW"}
          ]
        }
      ]
    },
    {
      "id": "human-rights-law",
      "title": "Human Rights Law",
      "semester": "Semester 6",
      "url": "",
      "units": [
        {
          "unitNo": 1,
          "title": "Concept, Evolution & Universal Declaration of Human Rights (UDHR)",
          "topics": [
            {"id": "human-rights-law-u1-t1", "title": "1. Human Rights - Definition, Characteristics, Evolution & UDHR (1948)"}
          ]
        },
        {
          "unitNo": 2,
          "title": "Human Rights Protection in India & NHRC",
          "topics": [
            {"id": "human-rights-law-u2-t1", "title": "1. Protection of Human Rights Act, 1993 - NHRC, State Commissions & Constitutional Enforcement"}
          ]
        }
      ]
    },
    {
      "id": "drafting-pleading-conveyancing",
      "title": "Drafting, Pleading & Conveyancing (DPC)",
      "semester": "Semester 6",
      "url": "",
      "units": [
        {
          "unitNo": 1,
          "title": "Principles of Drafting & Civil, Criminal and Writ Pleadings",
          "topics": [
            {"id": "drafting-pleading-conveyancing-u1-t1", "title": "1. Pleadings - Plaint, Written Statement, Replication, Set-Off, Counter-Claim, FIR vs Complaint & Writ Petitions"}
          ]
        },
        {
          "unitNo": 2,
          "title": "Conveyancing - Deeds & Instruments",
          "topics": [
            {"id": "drafting-pleading-conveyancing-u2-t1", "title": "1. Conveyancing Essentials - Sale Deed, Mortgage vs Pledge, Lease, Gift Deed, Power of Attorney & Will"}
          ]
        }
      ]
    },
    {
      "id": "moot-court",
      "title": "Moot Court & Trial Advocacy",
      "semester": "Semester 6",
      "url": "",
      "units": [
        {
          "unitNo": 1,
          "title": "Moot Memorials, Oral Advocacy & PIL Writ Practice",
          "topics": [
            {"id": "moot-court-u1-t1", "title": "1. Moot Court Memorial Structure, Public Interest Litigation (PIL) & Writ Jurisdiction"}
          ]
        },
        {
          "unitNo": 2,
          "title": "Criminal Trial Advocacy - Cognizance, Bail & Dowry Death",
          "topics": [
            {"id": "moot-court-u2-t1", "title": "1. Criminal Moot Trial - Cognizance (Sec. 190 CrPC), Bail vs Anticipatory Bail & Dowry Death (Sec. 304B/498A IPC)"}
          ]
        }
      ]
    }
  ],
  "notes": {
    "law-of-taxation-u1-t1": {
      "id": "law-of-taxation-u1-t1",
      "subtitle": "Law of Taxation (Income Tax & GST) - Unit 1",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "Article 265 of the Constitution mandates that no tax shall be levied or collected except by authority of law. Under the Income Tax Act, 1961, income earned during the Previous Year is assessed in the Assessment Year based on Residential Status across five statutory heads of income, while agricultural income is exempt under Section 10(1).",
        "legalProvision": "Articles 246 and 265 (Seventh Schedule), Constitution of India; Sections 2(9), 3, 6, 10(1), and 14, Income Tax Act, 1961",
        "meaning": "Taxation is the primary revenue backbone of the Union, States, and Local Bodies. Direct taxes (like Income Tax) are borne directly by the assessee, whereas indirect taxes (like GST) are collected from consumers by suppliers and remitted to the Government.",
        "keyPoints": [
          "Constitutional Authority (Article 265): Neither the Union nor any State can levy or collect a tax without a valid statute enacted by a competent legislature under the Seventh Schedule.",
          "Previous Year vs Assessment Year: Previous Year (Section 3) is the financial year (April 1 to March 31) in which income is earned; Assessment Year (Section 2(9)) is the immediately following 12-month period in which that income is taxed.",
          "Residential Status (Section 6): Tax incidence depends on residential status (Resident and Ordinarily Resident, Resident but Not Ordinarily Resident, or Non-Resident), not citizenship.",
          "Five Heads of Income (Section 14): (1) Income from Salaries, (2) Income from House Property, (3) Profits and Gains of Business or Profession, (4) Capital Gains (Short-Term & Long-Term), and (5) Income from Other Sources.",
          "Agricultural Income (Section 10(1)): Exempt from central income tax (though aggregated for rate purposes in certain cases); excludes non-agricultural poultry/dairy business profits.",
          "Procedure & Relief: Includes Permanent Account Number (PAN), Advance Tax instalments, Tax Deducted at Source (TDS), and Double Taxation Avoidance Agreements (DTAA) under Sections 90-91."
        ],
        "caseLaws": [
          {
            "name": "Kunnathat Thathunni Moopil Nair v. State of Kerala",
            "citation": "AIR 1961 SC 552",
            "principle": "Held that a taxing statute is not immune from Fundamental Rights scrutiny and must satisfy Article 14 (non-arbitrariness) as well as Article 265."
          }
        ],
        "selfTest": [
          {
            "q": "What is the constitutional mandate under Article 265, and what are the five heads of income under Section 14 of the Income Tax Act, 1961?",
            "a": "Article 265 prohibits levying or collecting any tax without authority of law. The five heads are Salary, House Property, Business/Profession, Capital Gains, and Other Sources."
          }
        ],
        "visuals": []
      }
    },
    "law-of-taxation-u2-t1": {
      "id": "law-of-taxation-u2-t1",
      "subtitle": "Law of Taxation (Income Tax & GST) - Unit 2",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "The Goods and Services Tax (GST) Act, 2017 (101st Constitutional Amendment) unified India's indirect taxes into a destination-based consumption tax on 'supply' of goods and services. It operates via CGST, SGST/UTGST, and IGST, eliminating cascading tax-on-tax through seamless Input Tax Credit (ITC).",
        "legalProvision": "Articles 246A and 279A, Constitution of India; Sections 7, 8, 9, 16, and 22, Central Goods and Services Tax (CGST) Act, 2017",
        "meaning": "GST replaced multiple fragmented indirect taxes (excise duty, VAT, service tax, CST) with 'One Nation, One Tax.' Tax liability arises at the point of supply, and registered businesses offset tax paid on inputs against tax collected on outputs via Input Tax Credit.",
        "keyPoints": [
          "Kinds of GST: CGST (Central GST) and SGST/UTGST (State/UT GST) apply concurrently to intra-State supplies; IGST (Integrated GST) applies to inter-State supplies and imports.",
          "Composite Supply (Section 2(30) & 8(a)): Two or more taxable supplies naturally bundled in the ordinary course of business (e.g., goods sold with transit insurance); taxed at the rate of the principal supply.",
          "Mixed Supply (Section 2(74) & 8(b)): Two or more individual supplies bundled together for a single price that are not naturally bundled (e.g., a gift hamper of chocolates, watch, and juice); taxed at the highest applicable rate among the items.",
          "Input Tax Credit (Section 16): Allows a registered supplier to deduct GST paid on business inputs from output GST liability, provided he holds a tax invoice, has received the goods/services, the supplier has paid the tax to Government, and returns are filed.",
          "GST Council (Article 279A): Constitutional federal body chaired by the Union Finance Minister with State Finance Ministers to recommend GST rates, exemptions, and thresholds."
        ],
        "caseLaws": [
          {
            "name": "Union of India v. Mohit Minerals Pvt. Ltd.",
            "citation": "2022 10 SCC 700",
            "principle": "Held that recommendations of the GST Council under Article 279A have persuasive value reflecting cooperative federalism, and both Parliament and State Legislatures possess simultaneous legislative power under Article 246A."
          }
        ],
        "selfTest": [
          {
            "q": "How is tax rate determined for a Composite Supply versus a Mixed Supply under Section 8 of the CGST Act, 2017?",
            "a": "A Composite Supply is taxed at the rate of its principal supply, whereas a Mixed Supply is taxed at the highest tax rate applicable to any single item in the bundle."
          }
        ],
        "visuals": []
      }
    },
    "information-technology-law-u1-t1": {
      "id": "information-technology-law-u1-t1",
      "subtitle": "Information Technology & Cyber Law - Unit 1",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "The Information Technology Act, 2000 (based on the UNCITRAL Model Law on E-Commerce) grants legal recognition to electronic records and digital signatures, facilitates E-Governance, establishes extra-territorial cyber jurisdiction (Section 75), and provides conditional safe-harbour protection to intermediaries (Section 79).",
        "legalProvision": "Sections 1(2), 3, 4, 5, 6, 75, and 79, Information Technology Act, 2000; Section 65B, IEA / Section 63, BSA, 2023",
        "meaning": "Cyberspace is a borderless electronic medium of interconnected computer networks where traditional territorial jurisdiction breaks down. The IT Act, 2000 bridges technology and law by validating e-contracts, digital authentication, and electronic evidence.",
        "keyPoints": [
          "Cyberspace & Internet Jurisdiction: Because online transactions cross borders, courts apply tests like the 'Effects Test' and 'Zippo Sliding Scale' (passive vs interactive websites); under Section 75, the IT Act applies even to offences committed outside India if a computer resource in India is involved.",
          "Legal Recognition of Electronic Records & Digital Signatures (Sections 3-5): Electronic records and asymmetric-crypto Digital Signatures (verified by licensed Certifying Authorities) carry the same legal validity as paper documents and handwritten signatures.",
          "E-Governance (Sections 6-10): Authorizes government departments to accept online filings, issue digital licenses/permits, and publish official gazettes electronically.",
          "E-Commerce & Online Contracts (Section 10A): Validates contracts formed electronically (click-wrap, shrink-wrap, browse-wrap); dispatch and receipt rules under Section 13 determine where and when an online contract is concluded.",
          "Intermediary Liability & Safe Harbour (Section 79): ISPs, social media platforms, and marketplaces are exempt from liability for third-party user content if they observe due diligence and expeditiously remove unlawful content upon receiving a court or government order."
        ],
        "caseLaws": [
          {
            "name": "Shreya Singhal v. Union of India",
            "citation": "AIR 2015 SC 1523",
            "principle": "Struck down Section 66A of the IT Act as violative of Article 19(1)(a) and read down Section 79(3)(b) so intermediaries need to take down content only upon receiving actual knowledge via a court order or government notification."
          }
        ],
        "selfTest": [
          {
            "q": "Under what conditions does an intermediary enjoy 'safe harbour' exemption under Section 79 of the IT Act, 2000?",
            "a": "When its role is limited to providing access/hosting without initiating or modifying the transmission, it observes statutory due diligence, and it removes unlawful content upon receiving a court or government order."
          }
        ],
        "visuals": []
      }
    },
    "information-technology-law-u2-t1": {
      "id": "information-technology-law-u2-t1",
      "subtitle": "Information Technology & Cyber Law - Unit 2",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "Cyber crimes are unlawful acts where a computer is either a tool or a target—including hacking, data theft, identity theft, phishing, cyber stalking, cyber terrorism, and publishing obscene material. The IT Act, 2000 (Sections 43, 66-67B) provides both civil compensation and criminal punishment, complemented by the Digital Personal Data Protection Act, 2023.",
        "legalProvision": "Sections 43, 43A, 66, 66C, 66D, 66E, 66F, 67, 67A, and 67B, Information Technology Act, 2000; Digital Personal Data Protection Act, 2023",
        "meaning": "Cyber crimes exploit anonymity and global reach to commit financial fraud, privacy violations, and attacks on critical infrastructure. The 2008 Amendment to the IT Act introduced specific offences for identity theft, phishing, privacy violation, and cyber terrorism.",
        "keyPoints": [
          "Unauthorized Access & Hacking (Sections 43 & 66): Dishonestly or fraudulently accessing, downloading, or damaging a computer system or introducing viruses/Denial-of-Service attacks attracts up to 3 years' imprisonment and/or Rs. 5 lakh fine.",
          "Identity Theft & Phishing (Sections 66C & 66D): Fraudulently using another's password, electronic signature, or credit card details (Section 66C) or cheating by personation via computer resource (Section 66D).",
          "Violation of Privacy & Obscenity (Sections 66E, 67, 67A & 67B): Punishes capturing/publishing private images without consent (Section 66E), transmitting obscene or sexually explicit material (Sections 67-67A), and strictly punishes child sexual abuse material (Section 67B).",
          "Cyber Terrorism (Section 66F): Attacking critical information infrastructure to threaten India's unity, integrity, or sovereignty; punishable with imprisonment up to life.",
          "Data Protection & Privacy: Right to Privacy is a Fundamental Right under Article 21 (Puttaswamy); corporate failure to protect sensitive personal data attracts compensation (Section 43A), now strengthened by the Digital Personal Data Protection Act, 2023."
        ],
        "caseLaws": [
          {
            "name": "Justice K.S. Puttaswamy v. Union of India",
            "citation": "2017 10 SCC 1",
            "principle": "A 9-judge Constitution Bench unanimously held that the Right to Privacy (including informational and digital privacy) is an intrinsic part of Article 21."
          }
        ],
        "selfTest": [
          {
            "q": "Match the IT Act, 2000 sections for Hacking, Identity Theft, Privacy Violation, and Cyber Terrorism.",
            "a": "Hacking: Section 66; Identity Theft: Section 66C; Violation of Privacy: Section 66E; Cyber Terrorism: Section 66F."
          }
        ],
        "visuals": []
      }
    },
    "law-relating-to-women-u1-t1": {
      "id": "law-relating-to-women-u1-t1",
      "subtitle": "Law Relating to Women - Unit 1",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "The Indian Constitution guarantees gender justice through equality before law (Article 14), special protective laws for women (Article 15(3)), equal pay for equal work (Article 39(d)), maternity relief (Article 42), Uniform Civil Code (Article 44), and renouncing practices derogatory to women's dignity (Article 51A(e)).",
        "legalProvision": "Articles 14, 15(1), 15(3), 16, 21, 39(d), 42, 44, and 51A(e), Constitution of India; Section 6, Hindu Succession (Amendment) Act, 2005",
        "meaning": "While women enjoyed high educational and social status as 'Ardhanginis' during the early Vedic period, later historical restrictions marginalized them. Modern Indian constitutional and statutory law actively dismantles gender discrimination in employment, personal laws, and inheritance.",
        "keyPoints": [
          "Fundamental Rights (Articles 14, 15 & 16): Prohibits sex discrimination while empowering the State under Article 15(3) to enact affirmative protective legislation for women and children.",
          "Directive Principles (Articles 39(d), 42 & 44): Mandates equal pay for equal work for men and women (enforced via Equal Remuneration Act, 1976), just and humane working conditions with maternity relief, and endeavouring to secure a Uniform Civil Code (UCC) across India.",
          "Fundamental Duty (Article 51A(e)): Imposes a constitutional duty on every citizen to renounce practices derogatory to the dignity of women.",
          "Equal Property Rights of Hindu Women: Under Section 14 of the Hindu Succession Act, 1956, a Hindu female's limited estate became absolute; the 2005 Amendment (Section 6) made daughters coparceners by birth with equal rights and liabilities as sons (Vineeta Sharma v. Rakesh Sharma, 2020).",
          "Maintenance & Bigamy Safeguards: Secular maintenance under Section 125 CrPC (Section 144 BNSS) protects wives across all religions; conversion to Islam to contract a second marriage without dissolving the first Hindu marriage is void and punishable for bigamy (Sarla Mudgal)."
        ],
        "caseLaws": [
          {
            "name": "Sarla Mudgal v. Union of India",
            "citation": "AIR 1995 SC 1531",
            "principle": "Held that a Hindu husband who converts to Islam solely to marry a second wife without dissolving his first marriage commits bigamy under Section 494 IPC, and urged the State to enact a Uniform Civil Code under Article 44."
          },
          {
            "name": "Vineeta Sharma v. Rakesh Sharma",
            "citation": "2020 9 SCC 1",
            "principle": "Confirmed that daughters have equal coparcenary rights by birth under the 2005 Hindu Succession Amendment irrespective of whether the father was alive on 9 September 2005."
          }
        ],
        "selfTest": [
          {
            "q": "Which constitutional articles empower special laws for women, mandate equal pay for equal work, and direct a Uniform Civil Code?",
            "a": "Article 15(3) (special provisions for women), Article 39(d) (equal pay for equal work), and Article 44 (Uniform Civil Code)."
          }
        ],
        "visuals": []
      }
    },
    "law-relating-to-women-u2-t1": {
      "id": "law-relating-to-women-u2-t1",
      "subtitle": "Law Relating to Women - Unit 2",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "India protects women through targeted socio-legal statutes—Dowry Prohibition Act, 1961, Protection of Women from Domestic Violence Act, 2005, POSH Act, 2013, MTP Act, 1971, PCPNDT Act, 1994, and Maternity Benefit Act, 1961—aligned with the UN CEDAW Convention (1979), the 'Magna Carta of Women's Rights.'",
        "legalProvision": "Dowry Prohibition Act, 1961; PWDVA, 2005; POSH Act, 2013; MTP Act, 1971 (2021 Amend.); PCPNDT Act, 1994; Maternity Benefit Act, 1961 (2017 Amend.); CEDAW (1979)",
        "meaning": "Beyond criminal law (Sections 498A and 304B IPC / Sections 85 and 80 BNS), Indian Parliament enacted comprehensive civil and welfare laws to combat dowry harassment, domestic abuse, female foeticide, and workplace sexual harassment.",
        "keyPoints": [
          "Dowry Prohibition Act, 1961: Criminalizes giving, taking, or demanding dowry (minimum 5 years' imprisonment plus fine); complements Section 304B IPC (dowry death) and Section 498A IPC (cruelty).",
          "Domestic Violence Act (PWDVA, 2005): Provides swift civil remedies—Protection Orders, Residence Orders (right to shared household), Monetary Relief, and Custody Orders—covering physical, verbal, emotional, sexual, and economic abuse.",
          "Sexual Harassment at Workplace (POSH Act, 2013): Codified Vishaka Guidelines; mandates every workplace with 10+ employees to constitute an Internal Complaints Committee (ICC) headed by a senior woman.",
          "MTP Act, 1971 (amended 2021) & PCPNDT Act, 1994: MTP Act legalizes safe medical termination of pregnancy up to 20 weeks (24 weeks for special categories); PCPNDT Act strictly bans pre-natal sex determination to stop female foeticide.",
          "Maternity Benefit Act, 1961 (amended 2017): Grants 26 weeks of paid maternity leave (for up to two children) and strictly prohibits dismissing a woman during pregnancy/maternity absence (Section 12).",
          "CEDAW (1979): International UN Bill of Rights for Women ratified by India, obligating States to eliminate all forms of legal, political, and workplace discrimination against women."
        ],
        "caseLaws": [
          {
            "name": "Vishaka v. State of Rajasthan",
            "citation": "AIR 1997 SC 3011",
            "principle": "Relied on Articles 14, 19, 21 and CEDAW to lay down binding guidelines against sexual harassment of women at the workplace, later enacted as the POSH Act, 2013."
          }
        ],
        "selfTest": [
          {
            "q": "Why is CEDAW (1979) called the Magna Carta of Women's Rights, and how did the Supreme Court apply it in India?",
            "a": "CEDAW is the comprehensive UN treaty binding States to eliminate all discrimination against women; the Supreme Court relied directly on CEDAW in Vishaka v. State of Rajasthan (1997) to frame workplace sexual harassment guidelines."
          }
        ],
        "visuals": []
      }
    },
    "human-rights-law-u1-t1": {
      "id": "human-rights-law-u1-t1",
      "subtitle": "Human Rights Law - Unit 1",
      "readTime": "4 min read",
      "url": "",
      "en": {
        "inOneMinute": "Human Rights are universal, inalienable birthrights inherent to every human being by virtue of human dignity, regardless of nationality, race, gender, or religion. Adopted by the UN General Assembly on 10 December 1948 in Paris, the Universal Declaration of Human Rights (UDHR) is the foundational global charter of human rights.",
        "legalProvision": "Universal Declaration of Human Rights (UDHR, 1948); ICCPR (1966) & ICESCR (1966); UN Charter (1945)",
        "meaning": "Historically shaped by struggles against tyranny, slavery, colonialism, and World War II atrocities, human rights evolved across three generations: Civil and Political Rights (1st generation), Economic, Social and Cultural Rights (2nd generation), and Collective/Solidarity Rights such as clean environment and peace (3rd generation).",
        "keyPoints": [
          "Core Characteristics: Universal (applicable everywhere), Inalienable (cannot be arbitrarily taken away or waived), Inherent (acquired by birth), Indivisible and Interdependent, and enforceable against State excess.",
          "Historical Evolution: Progressed from Magna Carta (1215), English Bill of Rights (1689), American Declaration of Independence (1776), and French Declaration of Rights of Man (1789) to the UN Charter (1945) and UDHR (1948).",
          "UDHR (10 December 1948 — Human Rights Day): Contains a Preamble and 30 Articles proclaiming that 'all human beings are born free and equal in dignity and rights' (Article 1), guaranteeing right to life, equality, prohibition of slavery/torture, fair trial, and socio-economic rights.",
          "International Bill of Human Rights: Comprises the UDHR (1948) plus two legally binding treaties—the International Covenant on Civil and Political Rights (ICCPR, 1966) and the International Covenant on Economic, Social and Cultural Rights (ICESCR, 1966).",
          "Impact on India: Directly inspired Part III (Fundamental Rights) and Part IV (Directive Principles of State Policy) of the Constitution of India."
        ],
        "caseLaws": [
          {
            "name": "Chairman, Railway Board v. Chandrima Das",
            "citation": "AIR 2000 SC 988",
            "principle": "Relied on the UDHR (1948) and Article 21 to award public-law compensation to a foreign national victim of sexual assault, holding that human rights apply to all human beings, not just citizens."
          }
        ],
        "selfTest": [
          {
            "q": "What three instruments together form the International Bill of Human Rights?",
            "a": "The Universal Declaration of Human Rights (UDHR, 1948), the International Covenant on Civil and Political Rights (ICCPR, 1966), and the International Covenant on Economic, Social and Cultural Rights (ICESCR, 1966)."
          }
        ],
        "visuals": []
      }
    },
    "human-rights-law-u2-t1": {
      "id": "human-rights-law-u2-t1",
      "subtitle": "Human Rights Law - Unit 2",
      "readTime": "4 min read",
      "url": "",
      "en": {
        "inOneMinute": "The Protection of Human Rights Act, 1993 defines human rights as rights relating to life, liberty, equality, and dignity guaranteed by the Constitution or international covenants (Section 2(1)(d)). It established the National Human Rights Commission (NHRC), State Human Rights Commissions (SHRCs), and Human Rights Courts.",
        "legalProvision": "Protection of Human Rights Act, 1993 (Sections 2(1)(d), 3, 12, 13, 21, and 30); Articles 32 and 226, Constitution of India",
        "meaning": "To supplement constitutional writ remedies under Articles 32 and 226, Parliament created independent statutory watchdogs (NHRC and SHRCs) empowered to inquire suo motu into custodial deaths, police excesses, and public-servant human rights violations.",
        "keyPoints": [
          "Statutory Definition (Section 2(1)(d)): Rights relating to life, liberty, equality, and dignity of the individual guaranteed by the Constitution or embodied in the International Covenants (ICCPR/ICESCR) and enforceable by Indian courts.",
          "Composition of NHRC (Section 3, amended 2019): Chairperson (former Chief Justice of India or Supreme Court Judge) plus full-time members (SC/HC judges and human rights experts) and ex-officio chairpersons of national commissions (SC, ST, Women, Minorities, Backward Classes, Child Rights).",
          "Functions & Powers (Sections 12-13): Inquire suo motu or on petition into human rights violations or negligence by public servants, visit jails/detention centres, review constitutional safeguards, and exercise civil court powers to summon witnesses and documents.",
          "Limitations: NHRC recommendations are advisory (not binding orders), it cannot inquire into matters older than 1 year (Section 36(2)), and it has limited inquiry jurisdiction over Armed Forces (Section 19).",
          "State Commissions & Human Rights Courts (Sections 21 & 30): States constitute SHRCs for State/Concurrent List matters, and Session Courts may be specified as Human Rights Courts for speedy trial of human rights offences."
        ],
        "caseLaws": [
          {
            "name": "Paramjit Kaur v. State of Punjab",
            "citation": "1999 2 SCC 131",
            "principle": "Held that when the Supreme Court refers a matter to the NHRC under Article 32, the NHRC acts as an expert body of the Court and is not fettered by the 1-year limitation under Section 36(2)."
          }
        ],
        "selfTest": [
          {
            "q": "What are the key powers and two statutory limitations of the National Human Rights Commission (NHRC)?",
            "a": "NHRC can inquire suo motu into public-servant violations, inspect jails, and summon witnesses like a civil court; however, its recommendations are advisory and it normally cannot inquire into incidents older than 1 year."
          }
        ],
        "visuals": []
      }
    },
    "drafting-pleading-conveyancing-u1-t1": {
      "id": "drafting-pleading-conveyancing-u1-t1",
      "subtitle": "Drafting, Pleading & Conveyancing (DPC) - Unit 1",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "Pleadings are formal written statements of material facts (not evidence or law) filed by parties in court—Plaint (plaintiff's claim) and Written Statement (defendant's defence) under Order VI CPC. Criminal drafting covers FIR vs Complaint (Section 2(d) CrPC) and Bail Applications, while Constitutional drafting covers Writ Petitions (Articles 32 & 226) and PILs.",
        "legalProvision": "Orders VI, VII, and VIII, Code of Civil Procedure, 1908; Sections 2(d), 2(g), 2(h), and 154 CrPC; Articles 32, 226, and 227, Constitution of India",
        "meaning": "Drafting is the legal skill of expressing facts, claims, and rights with precision, clarity, and brevity. Pleadings narrow down the exact issues in dispute before a court, whereas Conveyancing drafts non-litigious documents transferring property or legal rights.",
        "keyPoints": [
          "Four Golden Rules of Pleadings (Order VI Rule 2 CPC): (1) Plead facts, not law, (2) Plead material facts only, (3) Plead facts, not evidence, and (4) State facts concisely in numbered paragraphs.",
          "Civil Pleadings: Plaint (Order VII—sets out cause of action, jurisdiction, valuation, prayer), Written Statement (Order VIII—specific denials, Set-Off, and Counter-Claim), and Replication (plaintiff's reply to new facts in Written Statement with court leave under Order VIII Rule 9).",
          "FIR vs Criminal Complaint: An FIR (Section 154 CrPC / Section 173 BNSS) is first-in-time information of a cognizable offence given to police; a Complaint (Section 2(d) CrPC) is an oral or written allegation made to a Magistrate requesting legal action.",
          "Inquiry vs Investigation: Inquiry (Section 2(g)) is conducted by a Magistrate or Court (other than trial); Investigation (Section 2(h)) is conducted by police for collecting evidence.",
          "Constitutional Pleadings: Writ Petitions under Article 32 (Supreme Court) and Article 226 (High Court) seeking Habeas Corpus, Mandamus, Prohibition, Certiorari, or Quo Warranto, plus Public Interest Litigation (PIL) and High Court superintendence under Article 227."
        ],
        "caseLaws": [
          {
            "name": "Virendra Kashinath Ravat v. Vinayak N. Joshi",
            "citation": "1999 1 SCC 47",
            "principle": "Reaffirmed Order VI Rule 2 CPC: pleadings must concisely state material facts so the opposite party is not taken by surprise, without pleading detailed evidence."
          }
        ],
        "selfTest": [
          {
            "q": "Distinguish between an FIR and a Criminal Complaint, and between Inquiry and Investigation.",
            "a": "An FIR is given to police for a cognizable offence, whereas a Complaint is made to a Magistrate for action. An Inquiry is conducted by a Magistrate/Court, whereas an Investigation is conducted by police to collect evidence."
          }
        ],
        "visuals": []
      }
    },
    "drafting-pleading-conveyancing-u2-t1": {
      "id": "drafting-pleading-conveyancing-u2-t1",
      "subtitle": "Drafting, Pleading & Conveyancing (DPC) - Unit 2",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "Conveyancing is the art of drafting deeds and legal instruments—such as Sale Deeds, Mortgage Deeds, Lease Deeds, Gift Deeds, Powers of Attorney, Wills, and Trust Deeds—that create, transfer, or extinguish property rights between parties.",
        "legalProvision": "Transfer of Property Act, 1882 (Sections 54, 58, 105, and 122); Registration Act, 1908 (Section 17); Indian Stamp Act, 1899; Powers of Attorney Act, 1882",
        "meaning": "A Deed is a formal written instrument signed, attested, stamped, and delivered to record a binding transfer of property or legal authority. Every well-drafted deed follows a standard structure: Title, Date & Parties, Recitals ('Whereas'), Testatum/Operative Clause, Schedule of Property, Testimonium, Signatures, and Attestation.",
        "keyPoints": [
          "Sale Deed (Section 54 TPA): Transfers absolute ownership of immovable property for a price paid or promised; requires stamp duty and compulsory registration if valued at Rs. 100 or more.",
          "Mortgage Deed vs Pledge: A Mortgage (Section 58 TPA) transfers an interest in specific immovable property as security for a loan (delivery of possession not always needed), whereas a Pledge (Section 172 ICA) bails movable goods as security.",
          "Gift Deed (Section 122 TPA): Voluntary transfer of existing property without consideration by Donor to Donee, accepted during the donor's lifetime; immovable gifts must be registered and attested by at least two witnesses.",
          "Lease Deed (Section 105 TPA): Transfers the right to enjoy immovable property for a fixed time in return for rent/premium; leases exceeding 1 year require compulsory registration.",
          "Power of Attorney (General vs Special) & Will: A Power of Attorney authorizes an agent to act on the principal's behalf; a Will (testamentary instrument) takes effect only after the testator's death and requires attestation by two witnesses (registration optional)."
        ],
        "caseLaws": [
          {
            "name": "Suraj Lamp & Industries Pvt. Ltd. v. State of Haryana",
            "citation": "2012 1 SCC 656",
            "principle": "Held that immovable property can be legally conveyed only through a duly stamped and registered Sale Deed, not through an unregistered Agreement to Sell or General Power of Attorney."
          }
        ],
        "selfTest": [
          {
            "q": "What is the key difference between a Mortgage and a Pledge, and what are the standard parts of a Conveyancing Deed?",
            "a": "Mortgage uses immovable property as loan security, while Pledge uses movable goods. Standard deed parts: Title, Date/Parties, Recitals, Operative Clause, Property Schedule, Signatures, and Attestation."
          }
        ],
        "visuals": []
      }
    },
    "moot-court-u1-t1": {
      "id": "moot-court-u1-t1",
      "subtitle": "Moot Court & Trial Advocacy - Unit 1",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "Moot Court trains law students in appellate advocacy through written Memorials (Petitioner and Respondent) and oral arguments before a simulated Bench. In Constitutional/PIL moots (such as the Rasoolpura Nala environmental flooding PIL), advocates argue locus standi, Article 21 (right to a healthy environment), Article 48A, and Writ of Mandamus.",
        "legalProvision": "Articles 21, 32, 47, 48A, 51A(g), 226, and 300, Constitution of India",
        "meaning": "A Moot Memorial follows a strict appellate structure so judges can quickly grasp jurisdiction, issues, legal authorities, and relief sought. In environmental PIL moots, petitioners invoke relaxed locus standi and State public-trust duties, while respondents raise Act of God, statutory compliance, and citizens' fundamental duties under Article 51A(g).",
        "keyPoints": [
          "Standard Moot Memorial Structure: Cover Page (Blue for Petitioner/Appellant, Red for Respondent), Table of Contents, Index of Authorities, Statement of Jurisdiction, Statement of Facts, Issues Raised, Summary of Arguments, Arguments Advanced, and Prayer.",
          "Public Interest Litigation (PIL) & Locus Standi: Any public-spirited citizen may file a PIL under Articles 32 or 226 to redress public injury (e.g., environmental pollution, illegal nala encroachments) without personal gain.",
          "Petitioner's Core Environmental Arguments (Rasoolpura Nala Moot): Right to life under Article 21 includes a clean, flood-free environment; State failed its duty under Articles 47 and 48A and Land Grabbing laws; seeks Writ of Mandamus to remove encroachments, survey boundaries, and impose exemplary compensation.",
          "Respondent's Core Defences: Heavy rainfall was an unforeseen 'Act of God' (Vis Major), municipal authorities are taking ongoing clearance steps, citizens violated their duty under Article 51A(g) by dumping garbage (Sections 268-269 IPC public nuisance), and alternative statutory remedies exist.",
          "Oral Advocacy Etiquette: Address the Bench respectfully ('May it please Your Lordships'), answer judicial questions directly before returning to submissions, and manage time strictly."
        ],
        "caseLaws": [
          {
            "name": "M.C. Mehta v. Kamal Nath",
            "citation": "1997 1 SCC 388",
            "principle": "Established the Public Trust Doctrine in India, holding that natural water bodies and ecosystems are held by the State in trust for the public and cannot be encroached upon for private gain."
          },
          {
            "name": "S.P. Gupta v. Union of India",
            "citation": "AIR 1982 SC 149",
            "principle": "Expanded locus standi in India, firmly establishing Public Interest Litigation (PIL) so any public-spirited citizen can approach constitutional courts on behalf of aggrieved communities."
          }
        ],
        "selfTest": [
          {
            "q": "What are the essential sections of a Moot Court Memorial, and how do Petitioner and Respondent frame an environmental PIL moot?",
            "a": "A Memorial includes Jurisdiction, Facts, Issues, Summary of Arguments, Arguments Advanced, and Prayer. Petitioner relies on Article 21, Article 48A, and Writ of Mandamus; Respondent relies on Act of God, Article 51A(g) citizen duty, and alternative remedies."
          }
        ],
        "visuals": []
      }
    },
    "moot-court-u2-t1": {
      "id": "moot-court-u2-t1",
      "subtitle": "Moot Court & Trial Advocacy - Unit 2",
      "readTime": "5 min read",
      "url": "",
      "en": {
        "inOneMinute": "Criminal Moot Trials test mastery of CrPC/BNSS procedure—Magistrate cognizance (Section 190 CrPC), Bail vs Anticipatory Bail (Sections 436-439 CrPC), Sessions Court trial jurisdiction, and criminal appeals (Section 374 CrPC)—commonly applied to Dowry Death (Section 304B IPC), Cruelty (Section 498A IPC), and Statutory Presumption (Section 113B IEA).",
        "legalProvision": "Sections 190, 374, 436-439 CrPC (BNSS equivalents); Sections 304B & 498A IPC (Sections 80 & 85 BNS); Section 113B IEA (Section 118 BSA)",
        "meaning": "In a criminal moot or trial, the prosecution must prove every statutory ingredient beyond reasonable doubt, while the defence challenges missing links (such as absence of a dowry demand 'soon before death') to prevent the statutory presumption under Section 113B from operating.",
        "keyPoints": [
          "Cognizance of Offences (Section 190 CrPC): A Magistrate takes cognizance upon (1) receiving a complaint, (2) a police report (charge sheet), or (3) information from another person or his own knowledge.",
          "Warrant vs Summons Case & Jurisdiction: Offences punishable with death, life imprisonment, or over 2 years' imprisonment are Warrant Cases; Section 304B IPC (dowry death, 7 years to life) is a cognizable, non-bailable, non-compoundable offence triable exclusively by a Court of Session.",
          "Bail vs Anticipatory Bail: Regular Bail (Sections 436, 437, 439 CrPC) is sought after arrest; Anticipatory Bail (Section 438 CrPC / Section 482 BNSS) is sought from the Sessions Court or High Court in apprehension of arrest.",
          "Four Ingredients of Dowry Death (Section 304B IPC / Section 80 BNS): (1) Death caused by burns, bodily injury, or unnatural circumstances, (2) Within 7 years of marriage, (3) Subjected to cruelty or harassment by husband/relatives 'soon before her death,' and (4) Such cruelty was in connection with a demand for dowry.",
          "Statutory Presumption (Section 113B IEA / Section 118 BSA) & Appeals (Section 374 CrPC): Once the prosecution proves all four ingredients, the Court 'shall presume' the accused caused the dowry death; appeals from Sessions Court convictions lie to the High Court under Section 374(2) CrPC."
        ],
        "caseLaws": [
          {
            "name": "Kans Raj v. State of Punjab",
            "citation": "AIR 2000 SC 2324",
            "principle": "Clarified that 'soon before her death' under Section 304B IPC is a relative term requiring a proximate and live link between dowry-related cruelty and the unnatural death."
          }
        ],
        "selfTest": [
          {
            "q": "What are the four essential ingredients required to trigger the statutory presumption of Dowry Death under Section 304B IPC and Section 113B IEA?",
            "a": "Unnatural death (burns/injury), within 7 years of marriage, cruelty or harassment by husband/relatives soon before death, and a live nexus to a demand for dowry."
          }
        ],
        "visuals": []
      }
    }
  }
}
'@

$packPath = Join-Path $dataDir "sem6_handcrafted_pack.json"
[System.IO.File]::WriteAllText($packPath, $sem6Json, $u)

Write-Host "`n=== 1. Merging Hand-Crafted Semester 6 Pack into www/nyayasaral_db.json (Zero Overlap) ===" -ForegroundColor Cyan
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

print(f"[PASS] Merged Semester 6 Hand-Crafted Notes: +{added_subjs} subjects, +{added_topics} English topics (Total topics now: {len(notes)})")
'@

$tmpPy = Join-Path $env:TEMP "ls_merge_sem6.py"
[System.IO.File]::WriteAllText($tmpPy, $pyMerge, $u)
python -u $tmpPy (Join-Path $root "www\nyayasaral_db.json") $packPath
if ($LASTEXITCODE -ne 0) { throw "Merge failed!" }

if ($PushOta) {
  Write-Host "`n=== 2. Running Built-In EN -> TE/HI Auto-Converter & Deploying Live OTA ===" -ForegroundColor Cyan
  & (Join-Path $root "Push-LawStudyes-OTA.ps1") -Message "Added Hand-Crafted Semester 6 Subjects (Taxation, IT Law, Women Law, Human Rights, DPC, Moot Court) + Auto TE/HI"
}