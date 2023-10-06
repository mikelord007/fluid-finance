import FungibleToken from "../standards/FungibleToken.cdc"

pub contract Lending_Borrow {
    pub var borrowLimitPerBucket: UFix64 // Max Percentage of Debt a bucket can have, over which assets will be liquidated 
    pub let supplyTokensLimit : {String : UFix64} // Type Identifier of Token : Hard Upper limit on amount of tokens
    pub let borrowTokensLimit : {String : UFix64} // Type Identifier of Token : Percentage of max borrowable from pool
    pub let suppliedTokens: {UInt64: {String: UFix64}} // UUID of liquidity Bucket : {Type Identifier of Token : Amount of supply}
    pub let borrowedTokens: {UInt64: {String: UFix64}} // UUID of liquidity Bucket : {Type Identifier of Token : Amount of debt}

    pub let tokenVaults: @{String: FungibleToken.Vault} // Type Identifier of Token : Vault

    pub let AdminResourceStoragePath: StoragePath
    pub let bucketListStoragePath: StoragePath
    pub let bucketListPublicPath: PublicPath
    pub let liquidityBucketStorageTemplate: String
    
    pub resource bucketList {
        pub let holdingBucketsList: [UInt64]

        access(contract) fun addBucketToList(bucketID: UInt64) {
            self.holdingBucketsList.append(bucketID)
        }

        access(contract) fun removeBucketToList(bucketID: UInt64) {
            self.holdingBucketsList.remove(at: self.holdingBucketsList.firstIndex(of: bucketID)!)
        }

        init() {
            self.holdingBucketsList = []
        }
    }
    pub resource liquidityBucket {

        access(contract) fun supplyTokens(tokenIdentifier: String, amount: UFix64) {
            Lending_Borrow.suppliedTokens[self.uuid] = {tokenIdentifier: (Lending_Borrow.suppliedTokens[self.uuid]![tokenIdentifier] != nil ? Lending_Borrow.suppliedTokens[self.uuid]![tokenIdentifier]! : 0.0) + amount} 
        }

        access(contract) fun unSupplyTokens(tokenIdentifier: String, amount: UFix64) {
            Lending_Borrow.suppliedTokens[self.uuid] = {tokenIdentifier: (Lending_Borrow.suppliedTokens[self.uuid]![tokenIdentifier] != nil ? Lending_Borrow.suppliedTokens[self.uuid]![tokenIdentifier]! : 0.0) - amount}

            assert(!Lending_Borrow.checkIfBucketIsUnderCollateralized(bucket: self.uuid), message : "Undercollateralized UnSupply")
        }

        access(contract) fun borrowTokens(tokenIdentifier: String, amount: UFix64) {
            Lending_Borrow.borrowedTokens[self.uuid] = {tokenIdentifier: (Lending_Borrow.borrowedTokens[self.uuid]![tokenIdentifier] != nil ? Lending_Borrow.borrowedTokens[self.uuid]![tokenIdentifier]! : 0.0) + amount}

            assert(!Lending_Borrow.checkIfBucketIsUnderCollateralized(bucket: self.uuid), message : "Undercollateralized Borrow")
        }

        access(contract) fun repayTokens(tokenIdentifier: String, amount: UFix64) {
            Lending_Borrow.borrowedTokens[self.uuid] = {tokenIdentifier: (Lending_Borrow.borrowedTokens[self.uuid]![tokenIdentifier] != nil ? Lending_Borrow.borrowedTokens[self.uuid]![tokenIdentifier]! : 0.0) - amount}
        }

        init() {
            Lending_Borrow.suppliedTokens[self.uuid] = {}
            Lending_Borrow.borrowedTokens[self.uuid] = {}
        }
    }

    pub resource Administrator {
        pub fun modifyBorrowLimitPerBucket(newLimit : UFix64) {
            Lending_Borrow.borrowLimitPerBucket = newLimit
        }

        pub fun modifySupplyTokensLimit(supplyToken: String, limit: UFix64) {
            Lending_Borrow.supplyTokensLimit[supplyToken] = limit
        }

        pub fun modifyBorrowTokensLimit(borrowToken: String, limit: UFix64) {
            Lending_Borrow.borrowTokensLimit[borrowToken] = limit
        }

        pub fun initTokenVault(tokenIdentifier: String, vault: @FungibleToken.Vault): @FungibleToken.Vault? {
            if(Lending_Borrow.tokenVaults[tokenIdentifier] == nil ) {
                Lending_Borrow.tokenVaults[tokenIdentifier] <-! vault
                return nil
            }

            return <- vault
        }

        pub fun liquidateUnderCollateralizedBuckets() {
            Lending_Borrow.borrowedTokens.forEachKey(fun (key: UInt64): Bool {
                let underCollateralized = Lending_Borrow.checkIfBucketIsUnderCollateralized(bucket: key)

                if(underCollateralized) {
                    Lending_Borrow.suppliedTokens.insert(key: key, {})
                    Lending_Borrow.borrowedTokens.insert(key: key, {})
                }

                return true
            })
        }
    }

    pub fun supply(supplyTokenVault: @FungibleToken.Vault, existingLiquidityBucket: @liquidityBucket?, bucketList: &bucketList): @liquidityBucket {
        pre {
            self.supplyTokensLimit.containsKey(supplyTokenVault.getType().identifier): "Can't supply this token"
            supplyTokenVault.balance <= self.supplyTokensLimit[supplyTokenVault.getType().identifier]! : "Amount greater than limit"
            supplyTokenVault.balance >= 0.0 : "Are you joking bruv"
        }
        post {
            self.supplyTokensLimit[tokenVaultTypeIdentifier]! <= self.totalSupplied(tokenIdentifier: tokenVaultTypeIdentifier) : "supply exceeds limit"
        }

        let tokenVaultTypeIdentifier = supplyTokenVault.getType().identifier
        let supplyAmount = supplyTokenVault.balance

        self.depositToVault(tokenIdentifier: tokenVaultTypeIdentifier, supplyVault: <- supplyTokenVault)

        if(existingLiquidityBucket != nil) {
            let returnBucket <- existingLiquidityBucket!
            returnBucket.supplyTokens(tokenIdentifier: tokenVaultTypeIdentifier, amount: supplyAmount)
            return <- returnBucket
        }
        else {
            destroy existingLiquidityBucket
        }

        let newBucket <- create liquidityBucket()
        newBucket.supplyTokens(tokenIdentifier: tokenVaultTypeIdentifier, amount: supplyAmount)
        bucketList.addBucketToList(bucketID: newBucket.uuid)
        return <- newBucket
    }

    pub fun unsupply(bucket: &liquidityBucket, tokenIdentifier: String, amount: UFix64): @FungibleToken.Vault {
        pre {
            self.supplyTokensLimit.containsKey(tokenIdentifier): "Unsupported tokenIdentifier"
            amount >= 0.0 : "Are you joking bruv"
        }

        bucket.unSupplyTokens(tokenIdentifier: tokenIdentifier, amount: amount) // checks if un supplying doesn't leave bucket undercollateralized
        return <- self.withdrawFromVault(tokenIdentifier: tokenIdentifier, amount: amount)
    }

    pub fun borrow(bucket: &liquidityBucket, tokenIdentifier: String, amount: UFix64): @FungibleToken.Vault {
        pre {
            self.borrowTokensLimit.containsKey(tokenIdentifier): "Unsupported tokenIdentifier"
            amount >= 0.0 : "Are you joking bruv"
        }

        bucket.borrowTokens(tokenIdentifier: tokenIdentifier, amount: amount) // checks if borrowing doesn't leave bucket undercollateralized

        return <- self.withdrawFromVault(tokenIdentifier: tokenIdentifier, amount: amount)

    }

    pub fun repay(bucket: &liquidityBucket, tokenVault: @FungibleToken.Vault) {
        pre {
            self.borrowTokensLimit.containsKey(tokenVault.getType().identifier): "Unsupported tokenIdentifier"
            tokenVault.balance >= 0.0 : "Are you joking bruv"
        }

        let tokenTypeIdentifier = tokenVault.getType().identifier
        let tokenAmount = tokenVault.balance

        self.depositToVault(tokenIdentifier: tokenTypeIdentifier, supplyVault: <- tokenVault)
        bucket.repayTokens(tokenIdentifier: tokenTypeIdentifier, amount: tokenAmount)
    }

    pub fun createEmptyBucket(bucketList: &bucketList): @liquidityBucket {
        let bucket <- create liquidityBucket()
        bucketList.addBucketToList(bucketID: bucket.uuid)
        return <- bucket
    }

    pub fun createBucketList(): @bucketList {
        return <- create bucketList()
    }

    pub fun checkIfBucketIsUnderCollateralized(bucket: UInt64) : Bool {
        var totalSupply = 0.0
        var totalDebt = 0.0

        self.suppliedTokens[bucket]!.forEachKey(fun (key: String): Bool {
            totalSupply = self.fetchPriceFromOracle(type: key) * self.suppliedTokens[bucket]![key]! + totalSupply
            return true
        })

        self.borrowedTokens[bucket]!.forEachKey(fun (key: String): Bool {
            totalDebt = self.fetchPriceFromOracle(type: key) * self.borrowedTokens[bucket]![key]! + totalDebt
            return true
        })

        if(totalSupply == 0.0 && totalDebt == 0.0 ) {
            return false
        }
        
        return (totalDebt * 100.0) / totalSupply >= self.borrowLimitPerBucket
    }

    pub fun fetchPriceFromOracle(type: String): UFix64 {
        return 1.0 // assumption of fetching from oracle
    }

    pub fun totalSupplied(tokenIdentifier: String): UFix64 {
        var totalSupplied = 0.0

        Lending_Borrow.suppliedTokens.forEachKey(fun (bucket: UInt64): Bool {
            
            if(Lending_Borrow.suppliedTokens[bucket]![tokenIdentifier] != nil) {
                totalSupplied = totalSupplied + self.fetchPriceFromOracle(type: tokenIdentifier) * Lending_Borrow.suppliedTokens[bucket]![tokenIdentifier]!
            }

            return true
        })

        return totalSupplied 
    }

    pub fun totalBorrowed(tokenIdentifier: String): UFix64 {
        var totalBorrowed = 0.0

        Lending_Borrow.borrowedTokens.forEachKey(fun (bucket: UInt64): Bool {
            
            if(Lending_Borrow.borrowedTokens[bucket]![tokenIdentifier] != nil) {
                totalBorrowed = totalBorrowed + self.fetchPriceFromOracle(type: tokenIdentifier) * Lending_Borrow.borrowedTokens[bucket]![tokenIdentifier]!
            }
            
            return true
        })

        return totalBorrowed
    }

    access(contract) fun depositToVault(tokenIdentifier: String, supplyVault: @FungibleToken.Vault) {
        var tempVault: @FungibleToken.Vault? <- nil
        tempVault <-> self.tokenVaults[tokenIdentifier]
        var finalVault <- tempVault!
        finalVault.deposit(from: <- supplyVault)
        let dumpVault <- self.tokenVaults[tokenIdentifier] <- finalVault
        
        destroy dumpVault
    }

    access(contract) fun withdrawFromVault(tokenIdentifier: String, amount: UFix64): @FungibleToken.Vault {
        var tempVault: @FungibleToken.Vault? <- nil
        tempVault <-> self.tokenVaults[tokenIdentifier]
        var finalVault <- tempVault!
        let returnVault <- finalVault.withdraw(amount: amount)
        let dumpVault <- self.tokenVaults[tokenIdentifier] <- finalVault
        
        destroy dumpVault
        
        return <- returnVault
    }

    init() {
        self.borrowLimitPerBucket = 80.00
        self.supplyTokensLimit = {}
        self.borrowTokensLimit = {}
        self.suppliedTokens = {}
        self.borrowedTokens = {}
        self.tokenVaults <- {}
        self.AdminResourceStoragePath = /storage/LandBadmin
        self.bucketListStoragePath = /storage/bucketList
        self.bucketListPublicPath = /public/bucketList
        self.liquidityBucketStorageTemplate = "liquidityBucket" // + add id at end

        self.account.save(<- create Administrator(), to: self.AdminResourceStoragePath)
    }

}