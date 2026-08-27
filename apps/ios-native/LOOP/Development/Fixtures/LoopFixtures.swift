import Foundation

/// Coherent sample data used for the sample environment and SwiftUI previews.
///
/// DEVELOPMENT ONLY. Production services never fall back to these values —
/// see `Services/Live` which surfaces a real unavailable state instead.
nonisolated enum LoopFixtures {

    // MARK: - Stable identifiers

    static func id(_ index: Int) -> UUID {
        let suffix = String(format: "%012d", index)
        return UUID(uuidString: "00000000-0000-4000-8000-\(suffix)")!
    }

    static let accountID = id(1)
    static let businessAccountID = id(2)
    static let userID = id(3)

    private static func daysAgo(_ days: Int) -> Date {
        LoopDate.adding(days: -days, to: LoopDate.startOfDay())
    }

    private static func daysAhead(_ days: Int) -> Date {
        LoopDate.adding(days: days, to: LoopDate.startOfDay())
    }

    // MARK: - Profile

    static var profile: LoopProfile {
        LoopProfile(
            user: LoopUser(
                id: userID,
                displayName: "Avery Sinclair",
                email: "avery@sinclairstudio.co",
                avatarURL: nil,
                createdAt: daysAgo(420)
            ),
            accounts: [
                LoopAccount(
                    id: accountID,
                    name: "Personal",
                    kind: .personal,
                    currencyCode: "USD",
                    createdAt: daysAgo(420)
                ),
                LoopAccount(
                    id: businessAccountID,
                    name: "Sinclair Studio",
                    kind: .business,
                    currencyCode: "USD",
                    createdAt: daysAgo(300)
                )
            ],
            activeAccountID: accountID,
            hasCompletedOnboarding: true
        )
    }

    // MARK: - Purchases and owned items

    static var purchases: [Purchase] {
        [
            Purchase(
                id: id(100),
                accountID: accountID,
                itemName: "Sony WH-1000XM5",
                merchant: "Best Buy",
                amount: .usd(349.99),
                purchasedAt: daysAgo(26),
                category: "Electronics",
                orderNumber: "BBY-4471902",
                returnWindow: ReturnWindow(
                    purchasedAt: daysAgo(26),
                    policyDays: 30,
                    policyNote: "30-day return with receipt, original packaging required."
                ),
                note: nil,
                transactionID: id(300),
                ownedItemID: id(200)
            ),
            Purchase(
                id: id(101),
                accountID: accountID,
                itemName: "Nike Air Max 270",
                merchant: "Nike",
                amount: .usd(86.42),
                purchasedAt: daysAgo(38),
                category: "Apparel",
                orderNumber: "NK-88213445",
                returnWindow: ReturnWindow(
                    purchasedAt: daysAgo(38),
                    policyDays: 60,
                    policyNote: "60-day wear test return."
                ),
                note: "Half size too small.",
                transactionID: id(301),
                ownedItemID: id(201)
            ),
            Purchase(
                id: id(102),
                accountID: accountID,
                itemName: "iPad (9th generation)",
                merchant: "Apple",
                amount: .usd(499.00),
                purchasedAt: daysAgo(410),
                category: "Electronics",
                orderNumber: "W1092884471",
                returnWindow: nil,
                note: nil,
                transactionID: id(302),
                ownedItemID: id(202)
            ),
            Purchase(
                id: id(103),
                accountID: accountID,
                itemName: "Dyson V12 Detect Slim",
                merchant: "Dyson",
                amount: .usd(649.99),
                purchasedAt: daysAgo(5),
                category: "Home",
                orderNumber: "DY-2299301",
                returnWindow: ReturnWindow(
                    purchasedAt: daysAgo(5),
                    policyDays: 30,
                    policyNote: "30-day money-back guarantee direct from Dyson."
                ),
                note: nil,
                transactionID: id(303),
                ownedItemID: id(203)
            ),
            Purchase(
                id: id(104),
                accountID: accountID,
                itemName: "Vitamix E310",
                merchant: "Costco",
                amount: .usd(349.95),
                purchasedAt: daysAgo(320),
                category: "Kitchen",
                orderNumber: "CO-7781234",
                returnWindow: nil,
                note: nil,
                transactionID: id(304),
                ownedItemID: id(204)
            ),
            Purchase(
                id: id(105),
                accountID: accountID,
                itemName: "Patagonia Nano Puff",
                merchant: "Patagonia",
                amount: .usd(178.50),
                purchasedAt: daysAgo(55),
                category: "Apparel",
                orderNumber: "PT-556201",
                returnWindow: ReturnWindow(
                    purchasedAt: daysAgo(55),
                    policyDays: 60,
                    policyNote: "Ironclad guarantee."
                ),
                note: "Returned — wrong colour.",
                transactionID: id(305),
                ownedItemID: nil
            ),
            Purchase(
                id: id(106),
                accountID: accountID,
                itemName: "Canon EOS R50",
                merchant: "B&H Photo",
                amount: .usd(679.00),
                purchasedAt: daysAgo(8),
                category: "Photography",
                orderNumber: "BH-1129047",
                returnWindow: ReturnWindow(
                    purchasedAt: daysAgo(8),
                    policyDays: 14,
                    policyNote: "14-day return on opened camera bodies."
                ),
                note: nil,
                transactionID: id(306),
                ownedItemID: id(205)
            )
        ]
    }

    static var ownedItems: [OwnedItem] {
        [
            OwnedItem(
                id: id(200),
                accountID: accountID,
                name: "Sony WH-1000XM5",
                merchant: "Best Buy",
                purchaseID: id(100),
                purchasedAt: daysAgo(26),
                originalPrice: .usd(349.99),
                condition: .likeNew,
                estimatedResaleValue: nil,
                estimateIsUserProvided: false,
                warrantyID: id(500),
                returnRecordID: nil,
                saleID: nil,
                isMarkedForSale: false,
                note: nil
            ),
            OwnedItem(
                id: id(201),
                accountID: accountID,
                name: "Nike Air Max 270",
                merchant: "Nike",
                purchaseID: id(101),
                purchasedAt: daysAgo(38),
                originalPrice: .usd(86.42),
                condition: .new,
                estimatedResaleValue: nil,
                estimateIsUserProvided: false,
                warrantyID: nil,
                returnRecordID: id(400),
                saleID: nil,
                isMarkedForSale: false,
                note: nil
            ),
            OwnedItem(
                id: id(202),
                accountID: accountID,
                name: "iPad (9th generation)",
                merchant: "Apple",
                purchaseID: id(102),
                purchasedAt: daysAgo(410),
                originalPrice: .usd(499.00),
                condition: .good,
                estimatedResaleValue: .usd(260.00),
                estimateIsUserProvided: true,
                warrantyID: nil,
                returnRecordID: nil,
                saleID: nil,
                isMarkedForSale: false,
                note: "Screen is clean, no case included."
            ),
            OwnedItem(
                id: id(203),
                accountID: accountID,
                name: "Dyson V12 Detect Slim",
                merchant: "Dyson",
                purchaseID: id(103),
                purchasedAt: daysAgo(5),
                originalPrice: .usd(649.99),
                condition: .new,
                estimatedResaleValue: nil,
                estimateIsUserProvided: false,
                warrantyID: id(501),
                returnRecordID: nil,
                saleID: nil,
                isMarkedForSale: false,
                note: nil
            ),
            OwnedItem(
                id: id(204),
                accountID: accountID,
                name: "Vitamix E310",
                merchant: "Costco",
                purchaseID: id(104),
                purchasedAt: daysAgo(320),
                originalPrice: .usd(349.95),
                condition: .good,
                estimatedResaleValue: .usd(150.00),
                estimateIsUserProvided: true,
                warrantyID: id(502),
                returnRecordID: nil,
                saleID: nil,
                isMarkedForSale: false,
                note: nil
            ),
            OwnedItem(
                id: id(205),
                accountID: accountID,
                name: "Canon EOS R50",
                merchant: "B&H Photo",
                purchaseID: id(106),
                purchasedAt: daysAgo(8),
                originalPrice: .usd(679.00),
                condition: .new,
                estimatedResaleValue: nil,
                estimateIsUserProvided: false,
                warrantyID: nil,
                returnRecordID: nil,
                saleID: nil,
                isMarkedForSale: false,
                note: nil
            ),
            OwnedItem(
                id: id(206),
                accountID: accountID,
                name: "Apple Watch Series 7",
                merchant: "Apple",
                purchaseID: nil,
                purchasedAt: daysAgo(720),
                originalPrice: .usd(399.00),
                condition: .good,
                estimatedResaleValue: .usd(185.00),
                estimateIsUserProvided: true,
                warrantyID: nil,
                returnRecordID: nil,
                saleID: id(600),
                isMarkedForSale: true,
                note: nil
            ),
            OwnedItem(
                id: id(207),
                accountID: accountID,
                name: "Nintendo Switch OLED",
                merchant: "Target",
                purchaseID: nil,
                purchasedAt: daysAgo(500),
                originalPrice: .usd(349.99),
                condition: .good,
                estimatedResaleValue: .usd(240.00),
                estimateIsUserProvided: true,
                warrantyID: nil,
                returnRecordID: nil,
                saleID: id(601),
                isMarkedForSale: true,
                note: nil
            ),
            OwnedItem(
                id: id(208),
                accountID: accountID,
                name: "Sigma 30mm f/1.4 lens",
                merchant: "KEH Camera",
                purchaseID: nil,
                purchasedAt: daysAgo(365),
                originalPrice: .usd(339.00),
                condition: .likeNew,
                estimatedResaleValue: .usd(210.00),
                estimateIsUserProvided: true,
                warrantyID: nil,
                returnRecordID: nil,
                saleID: id(602),
                isMarkedForSale: true,
                note: nil
            )
        ]
    }

    // MARK: - Protect

    static var returns: [ReturnRecord] {
        [
            ReturnRecord(
                id: id(400),
                accountID: accountID,
                purchaseID: id(101),
                itemName: "Nike Air Max 270",
                merchant: "Nike",
                status: .refundPending,
                reason: "Wrong size — half size too small.",
                startedAt: daysAgo(21),
                deadline: daysAhead(22),
                carrier: "UPS",
                trackingNumber: "1Z999AA10123456784",
                shippedAt: daysAgo(19),
                merchantReceivedAt: daysAgo(12),
                expectedRefund: .usd(86.42),
                refundID: id(450),
                documentIDs: [id(702), id(703)],
                note: nil
            ),
            ReturnRecord(
                id: id(401),
                accountID: accountID,
                purchaseID: id(105),
                itemName: "Patagonia Nano Puff",
                merchant: "Patagonia",
                status: .refunded,
                reason: "Wrong colour shipped.",
                startedAt: daysAgo(30),
                deadline: daysAgo(0),
                carrier: "USPS",
                trackingNumber: "9400110200881234567890",
                shippedAt: daysAgo(28),
                merchantReceivedAt: daysAgo(20),
                expectedRefund: .usd(178.50),
                refundID: id(451),
                documentIDs: [id(704)],
                note: nil
            )
        ]
    }

    static var refunds: [Refund] {
        [
            Refund(
                id: id(450),
                accountID: accountID,
                merchant: "Nike",
                itemName: "Nike Air Max 270",
                purchaseID: id(101),
                returnRecordID: id(400),
                expectedAmount: .usd(86.42),
                receivedAmount: nil,
                status: .pending,
                expectedDate: daysAgo(2),
                receivedDate: nil,
                openedAt: daysAgo(12),
                transactionID: id(307),
                note: "Merchant confirmed receipt on the warehouse scan."
            ),
            Refund(
                id: id(451),
                accountID: accountID,
                merchant: "Patagonia",
                itemName: "Patagonia Nano Puff",
                purchaseID: id(105),
                returnRecordID: id(401),
                expectedAmount: .usd(178.50),
                receivedAmount: .usd(178.50),
                status: .received,
                expectedDate: daysAgo(8),
                receivedDate: daysAgo(6),
                openedAt: daysAgo(20),
                transactionID: id(308),
                note: nil
            )
        ]
    }

    static var warranties: [Warranty] {
        [
            Warranty(
                id: id(500),
                accountID: accountID,
                ownedItemID: id(200),
                itemName: "Sony WH-1000XM5",
                provider: "Sony",
                kind: .manufacturer,
                coverageStart: daysAgo(26),
                coverageEnd: daysAhead(339),
                referenceNumber: "SNY-4471902",
                documentIDs: [],
                note: nil
            ),
            Warranty(
                id: id(501),
                accountID: accountID,
                ownedItemID: id(203),
                itemName: "Dyson V12 Detect Slim",
                provider: "Dyson",
                kind: .manufacturer,
                coverageStart: daysAgo(5),
                coverageEnd: daysAhead(725),
                referenceNumber: "DY-2299301",
                documentIDs: [],
                note: "2-year parts and labour."
            ),
            Warranty(
                id: id(502),
                accountID: accountID,
                ownedItemID: id(204),
                itemName: "Vitamix E310",
                provider: "Vitamix",
                kind: .manufacturer,
                coverageStart: daysAgo(320),
                coverageEnd: daysAhead(30),
                referenceNumber: "VM-8890021",
                documentIDs: [id(705)],
                note: "Register the machine before coverage ends to extend by 1 year."
            )
        ]
    }

    static var documents: [LoopDocument] {
        [
            LoopDocument(
                id: id(700),
                accountID: accountID,
                type: .receipt,
                filename: "best-buy-4471902.pdf",
                byteSize: 184_320,
                createdAt: daysAgo(26),
                target: .purchase(id(100)),
                storagePath: nil,
                note: nil
            ),
            LoopDocument(
                id: id(701),
                accountID: accountID,
                type: .receipt,
                filename: "nike-88213445.pdf",
                byteSize: 96_100,
                createdAt: daysAgo(38),
                target: .purchase(id(101)),
                storagePath: nil,
                note: nil
            ),
            LoopDocument(
                id: id(702),
                accountID: accountID,
                type: .returnConfirmation,
                filename: "nike-return-label.pdf",
                byteSize: 55_400,
                createdAt: daysAgo(21),
                target: .returnRecord(id(400)),
                storagePath: nil,
                note: nil
            ),
            LoopDocument(
                id: id(703),
                accountID: accountID,
                type: .shippingEvidence,
                filename: "ups-dropoff-receipt.jpg",
                byteSize: 412_000,
                createdAt: daysAgo(19),
                target: .returnRecord(id(400)),
                storagePath: nil,
                note: nil
            ),
            LoopDocument(
                id: id(704),
                accountID: accountID,
                type: .refundConfirmation,
                filename: "patagonia-refund.pdf",
                byteSize: 72_800,
                createdAt: daysAgo(6),
                target: .refund(id(451)),
                storagePath: nil,
                note: nil
            ),
            LoopDocument(
                id: id(705),
                accountID: accountID,
                type: .warranty,
                filename: "vitamix-warranty.pdf",
                byteSize: 128_400,
                createdAt: daysAgo(320),
                target: .warranty(id(502)),
                storagePath: nil,
                note: nil
            ),
            LoopDocument(
                id: id(706),
                accountID: accountID,
                type: .receipt,
                filename: "apple-ipad-receipt.pdf",
                byteSize: 143_900,
                createdAt: daysAgo(410),
                target: .purchase(id(102)),
                storagePath: nil,
                note: nil
            ),
            LoopDocument(
                id: id(707),
                accountID: accountID,
                type: .receipt,
                filename: "bh-1129047.pdf",
                byteSize: 118_200,
                createdAt: daysAgo(8),
                target: .purchase(id(106)),
                storagePath: nil,
                note: nil
            )
        ]
    }

    // MARK: - Sell

    static var sales: [SaleRecord] {
        [
            SaleRecord(
                id: id(600),
                accountID: accountID,
                ownedItemID: id(206),
                itemName: "Apple Watch Series 7",
                platform: "Swappa",
                grossAmount: .usd(185.00),
                fees: .usd(14.80),
                shippingCost: .usd(9.20),
                listedDate: daysAgo(38),
                soldDate: daysAgo(24),
                status: .sold,
                transactionID: id(309),
                note: nil
            ),
            SaleRecord(
                id: id(601),
                accountID: accountID,
                ownedItemID: id(207),
                itemName: "Nintendo Switch OLED",
                platform: "Facebook Marketplace",
                grossAmount: .usd(240.00),
                fees: .zero,
                shippingCost: .zero,
                listedDate: daysAgo(11),
                soldDate: nil,
                status: .pending,
                transactionID: nil,
                note: "Buyer collecting Saturday."
            ),
            SaleRecord(
                id: id(602),
                accountID: accountID,
                ownedItemID: id(208),
                itemName: "Sigma 30mm f/1.4 lens",
                platform: "eBay",
                grossAmount: .usd(210.00),
                fees: .usd(27.30),
                shippingCost: .usd(12.00),
                listedDate: daysAgo(29),
                soldDate: nil,
                status: .listed,
                transactionID: nil,
                note: nil
            )
        ]
    }

    // MARK: - Business

    static var customers: [Customer] {
        [
            Customer(
                id: id(800),
                accountID: accountID,
                name: "Marcus Johnson",
                company: "Johnson Lawn Care",
                email: "marcus@johnsonlawncare.com",
                phone: "(512) 555-0148",
                note: "Prefers phone calls before 9am.",
                createdAt: daysAgo(96),
                isArchived: false
            ),
            Customer(
                id: id(801),
                accountID: accountID,
                name: "Priya Raman",
                company: "Beacon Coffee",
                email: "priya@beaconcoffee.co",
                phone: "(512) 555-0192",
                note: "Opening a second location in the fall.",
                createdAt: daysAgo(58),
                isArchived: false
            ),
            Customer(
                id: id(802),
                accountID: accountID,
                name: "Elaine Wu",
                company: "Harbor Dental",
                email: "office@harbordental.com",
                phone: "(512) 555-0170",
                note: nil,
                createdAt: daysAgo(210),
                isArchived: false
            )
        ]
    }

    static var leads: [Lead] {
        [
            Lead(
                id: id(900),
                accountID: accountID,
                name: "Marcus Johnson",
                contactLabel: "marcus@johnsonlawncare.com",
                source: .referral,
                status: .converted,
                estimatedValue: .usd(850),
                note: "Referred by Harbor Dental.",
                createdAt: daysAgo(34),
                nextFollowUp: nil,
                customerID: id(800),
                opportunityID: id(1000),
                isArchived: false
            ),
            Lead(
                id: id(901),
                accountID: accountID,
                name: "Priya Raman",
                contactLabel: "(512) 555-0192",
                source: .website,
                status: .qualified,
                estimatedValue: .usd(1200),
                note: "Wants lifestyle photography for the new location.",
                createdAt: daysAgo(16),
                nextFollowUp: daysAgo(1),
                customerID: id(801),
                opportunityID: id(1001),
                isArchived: false
            ),
            Lead(
                id: id(902),
                accountID: accountID,
                name: "Tomas Reyes",
                contactLabel: "@reyesbuilds",
                source: .socialMedia,
                status: .new,
                estimatedValue: .usd(400),
                note: "DM asking about a one-page site.",
                createdAt: daysAgo(2),
                nextFollowUp: LoopDate.startOfDay(),
                customerID: nil,
                opportunityID: nil,
                isArchived: false
            ),
            Lead(
                id: id(903),
                accountID: accountID,
                name: "Harbor Dental",
                contactLabel: "office@harbordental.com",
                source: .repeatCustomer,
                status: .contacted,
                estimatedValue: .usd(600),
                note: "Annual refresh of patient handouts.",
                createdAt: daysAgo(9),
                nextFollowUp: daysAhead(4),
                customerID: id(802),
                opportunityID: nil,
                isArchived: false
            )
        ]
    }

    static var opportunities: [Opportunity] {
        [
            Opportunity(
                id: id(1000),
                accountID: accountID,
                title: "Website redesign",
                detail: "Five-page marketing site with booking form and seasonal offers.",
                customerID: id(800),
                leadID: id(900),
                estimatedValue: .usd(850),
                stage: .proposal,
                expectedCloseDate: daysAhead(6),
                quoteIDs: [id(1100)],
                note: nil,
                createdAt: daysAgo(30),
                isArchived: false
            ),
            Opportunity(
                id: id(1001),
                accountID: accountID,
                title: "Brand photography",
                detail: "Half-day shoot plus retouching for the new Beacon location.",
                customerID: id(801),
                leadID: id(901),
                estimatedValue: .usd(1200),
                stage: .negotiation,
                expectedCloseDate: daysAhead(2),
                quoteIDs: [id(1101)],
                note: "Priya asked about splitting into two payments.",
                createdAt: daysAgo(14),
                isArchived: false
            ),
            Opportunity(
                id: id(1002),
                accountID: accountID,
                title: "Patient handout system",
                detail: "Template set plus print coordination.",
                customerID: id(802),
                leadID: nil,
                estimatedValue: .usd(2400),
                stage: .won,
                expectedCloseDate: daysAgo(22),
                quoteIDs: [],
                note: nil,
                createdAt: daysAgo(70),
                isArchived: false
            )
        ]
    }

    static var quotes: [Quote] {
        [
            Quote(
                id: id(1100),
                accountID: accountID,
                reference: "Q-1042",
                title: "Website redesign",
                customerID: id(800),
                opportunityID: id(1000),
                lineItems: [
                    QuoteLineItem(id: id(1150), name: "Design system and page layouts", quantity: 1, unitPrice: 450),
                    QuoteLineItem(id: id(1151), name: "Build and integration", detail: "Hourly", quantity: 6, unitPrice: 55),
                    QuoteLineItem(id: id(1152), name: "Hosting setup and handover", quantity: 1, unitPrice: 45)
                ],
                discount: 0,
                taxRate: 0,
                currencyCode: "USD",
                status: .viewed,
                issuedAt: daysAgo(7),
                expiresAt: daysAhead(3),
                respondedAt: nil,
                note: "Includes one round of revisions.",
                isArchived: false
            ),
            Quote(
                id: id(1101),
                accountID: accountID,
                reference: "Q-1039",
                title: "Brand photography",
                customerID: id(801),
                opportunityID: id(1001),
                lineItems: [
                    QuoteLineItem(id: id(1153), name: "Half-day shoot", quantity: 1, unitPrice: 900),
                    QuoteLineItem(id: id(1154), name: "Retouched images", detail: "Per image", quantity: 12, unitPrice: 25)
                ],
                discount: 0,
                taxRate: 0,
                currencyCode: "USD",
                status: .sent,
                issuedAt: daysAgo(6),
                expiresAt: daysAhead(9),
                respondedAt: nil,
                note: nil,
                isArchived: false
            ),
            Quote(
                id: id(1102),
                accountID: accountID,
                reference: "Q-1044",
                title: "Seasonal campaign assets",
                customerID: id(802),
                opportunityID: nil,
                lineItems: [
                    QuoteLineItem(id: id(1155), name: "Campaign concept", quantity: 1, unitPrice: 300)
                ],
                discount: 0,
                taxRate: 0,
                currencyCode: "USD",
                status: .draft,
                issuedAt: LoopDate.startOfDay(),
                expiresAt: daysAhead(30),
                respondedAt: nil,
                note: nil,
                isArchived: false
            )
        ]
    }

    static var earnings: [BusinessEarning] {
        [
            BusinessEarning(
                id: id(1200),
                accountID: accountID,
                title: "Harbor Dental — patient handout system",
                customerID: id(802),
                opportunityID: id(1002),
                quoteID: nil,
                amount: .usd(2400),
                receivedAt: daysAgo(20),
                source: .opportunity,
                transactionID: id(310),
                note: nil
            ),
            BusinessEarning(
                id: id(1201),
                accountID: accountID,
                title: "Johnson Lawn Care — spring maintenance page",
                customerID: id(800),
                opportunityID: nil,
                quoteID: nil,
                amount: .usd(325),
                receivedAt: daysAgo(45),
                source: .manual,
                transactionID: id(311),
                note: nil
            ),
            BusinessEarning(
                id: id(1202),
                accountID: accountID,
                title: "Beacon Coffee — menu refresh",
                customerID: id(801),
                opportunityID: nil,
                quoteID: nil,
                amount: .usd(480),
                receivedAt: daysAgo(4),
                source: .manual,
                transactionID: id(312),
                note: nil
            )
        ]
    }

    // MARK: - Money

    static var transactions: [MoneyTransaction] {
        [
            MoneyTransaction(
                id: id(300),
                accountID: accountID,
                amount: .usd(349.99),
                direction: .outgoing,
                type: .purchase,
                title: "Sony WH-1000XM5",
                merchantOrSource: "Best Buy",
                category: "Electronics",
                occurredAt: daysAgo(26),
                status: .cleared,
                relatedRecord: .purchase(id(100)),
                note: nil
            ),
            MoneyTransaction(
                id: id(301),
                accountID: accountID,
                amount: .usd(86.42),
                direction: .outgoing,
                type: .purchase,
                title: "Nike Air Max 270",
                merchantOrSource: "Nike",
                category: "Apparel",
                occurredAt: daysAgo(38),
                status: .cleared,
                relatedRecord: .purchase(id(101)),
                note: nil
            ),
            MoneyTransaction(
                id: id(302),
                accountID: accountID,
                amount: .usd(499.00),
                direction: .outgoing,
                type: .purchase,
                title: "iPad (9th generation)",
                merchantOrSource: "Apple",
                category: "Electronics",
                occurredAt: daysAgo(410),
                status: .cleared,
                relatedRecord: .purchase(id(102)),
                note: nil
            ),
            MoneyTransaction(
                id: id(303),
                accountID: accountID,
                amount: .usd(649.99),
                direction: .outgoing,
                type: .purchase,
                title: "Dyson V12 Detect Slim",
                merchantOrSource: "Dyson",
                category: "Home",
                occurredAt: daysAgo(5),
                status: .cleared,
                relatedRecord: .purchase(id(103)),
                note: nil
            ),
            MoneyTransaction(
                id: id(304),
                accountID: accountID,
                amount: .usd(349.95),
                direction: .outgoing,
                type: .purchase,
                title: "Vitamix E310",
                merchantOrSource: "Costco",
                category: "Kitchen",
                occurredAt: daysAgo(320),
                status: .cleared,
                relatedRecord: .purchase(id(104)),
                note: nil
            ),
            MoneyTransaction(
                id: id(305),
                accountID: accountID,
                amount: .usd(178.50),
                direction: .outgoing,
                type: .purchase,
                title: "Patagonia Nano Puff",
                merchantOrSource: "Patagonia",
                category: "Apparel",
                occurredAt: daysAgo(55),
                status: .cleared,
                relatedRecord: .purchase(id(105)),
                note: nil
            ),
            MoneyTransaction(
                id: id(306),
                accountID: accountID,
                amount: .usd(679.00),
                direction: .outgoing,
                type: .purchase,
                title: "Canon EOS R50",
                merchantOrSource: "B&H Photo",
                category: "Photography",
                occurredAt: daysAgo(8),
                status: .cleared,
                relatedRecord: .purchase(id(106)),
                note: nil
            ),
            MoneyTransaction(
                id: id(307),
                accountID: accountID,
                amount: .usd(86.42),
                direction: .incoming,
                type: .refund,
                title: "Nike refund",
                merchantOrSource: "Nike",
                category: "Recovered",
                occurredAt: daysAgo(12),
                status: .pending,
                relatedRecord: .refund(id(450)),
                note: "Awaiting merchant processing."
            ),
            MoneyTransaction(
                id: id(308),
                accountID: accountID,
                amount: .usd(178.50),
                direction: .incoming,
                type: .refund,
                title: "Patagonia refund",
                merchantOrSource: "Patagonia",
                category: "Recovered",
                occurredAt: daysAgo(6),
                status: .cleared,
                relatedRecord: .refund(id(451)),
                note: nil
            ),
            MoneyTransaction(
                id: id(309),
                accountID: accountID,
                amount: .usd(161.00),
                direction: .incoming,
                type: .resale,
                title: "Apple Watch Series 7 resale",
                merchantOrSource: "Swappa",
                category: "Resale",
                occurredAt: daysAgo(24),
                status: .cleared,
                relatedRecord: .sale(id(600)),
                note: "Net of $14.80 fees and $9.20 shipping."
            ),
            MoneyTransaction(
                id: id(310),
                accountID: accountID,
                amount: .usd(2400.00),
                direction: .incoming,
                type: .businessIncome,
                title: "Harbor Dental — patient handout system",
                merchantOrSource: "Harbor Dental",
                category: "Business",
                occurredAt: daysAgo(20),
                status: .cleared,
                relatedRecord: .earning(id(1200)),
                note: nil
            ),
            MoneyTransaction(
                id: id(311),
                accountID: accountID,
                amount: .usd(325.00),
                direction: .incoming,
                type: .businessIncome,
                title: "Johnson Lawn Care — spring page",
                merchantOrSource: "Johnson Lawn Care",
                category: "Business",
                occurredAt: daysAgo(45),
                status: .cleared,
                relatedRecord: .earning(id(1201)),
                note: nil
            ),
            MoneyTransaction(
                id: id(312),
                accountID: accountID,
                amount: .usd(480.00),
                direction: .incoming,
                type: .businessIncome,
                title: "Beacon Coffee — menu refresh",
                merchantOrSource: "Beacon Coffee",
                category: "Business",
                occurredAt: daysAgo(4),
                status: .cleared,
                relatedRecord: .earning(id(1202)),
                note: nil
            ),
            MoneyTransaction(
                id: id(313),
                accountID: accountID,
                amount: .usd(64.20),
                direction: .outgoing,
                type: .fee,
                title: "Studio software subscription",
                merchantOrSource: "Adobe",
                category: "Software",
                occurredAt: daysAgo(9),
                status: .cleared,
                relatedRecord: nil,
                note: nil
            )
        ]
    }

    // MARK: - Snapshot

    static var snapshot: LoopDataSnapshot {
        LoopDataSnapshot(
            profile: profile,
            purchases: purchases,
            ownedItems: ownedItems,
            returns: returns,
            refunds: refunds,
            warranties: warranties,
            documents: documents,
            sales: sales,
            customers: customers,
            leads: leads,
            opportunities: opportunities,
            quotes: quotes,
            earnings: earnings,
            transactions: transactions,
            completedActionIDs: [:]
        )
    }
}
