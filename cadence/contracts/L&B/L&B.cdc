import FungibleToken from "../standards/FungibleToken.cdc"

pub contract Lending_Borrow {
    pub var borrowLimitPerBucket: UFix64 // Max Percentage of Debt a bucket can have, over which assets will be liquidated 
    pub let supplyTokensLimit : {Type : UFix64} // Type of Token : Hard Upper limit on amount of tokens
    pub let borrowTokensLimit : {Type : UFix64} // Type of Token : Percentage of max borrowable from pool
    pub let suppliedTokens: {UInt64: {Type: UFix64}} // UUID of liquidity Bucket : {Type of Token : Amount of supply}
    pub let borrowedTokens: {UInt64: {Type: UFix64}} // UUID of liquidity Bucket : {Type of Token : Amount of debt}

    pub let tokenVaults: @{Type: FungibleToken.Vault}
    pub let fungibleTokenContracts: {Type: FungibleToken}
 
    pub resource liquidityBucket {
        pub let suppliedTokens : &{Type: UFix64}?
        pub let borrowedTokens: &{Type: UFix64}?

        access(contract) fun supplyTokens(token: Type, amount: UFix64) {
            self.suppliedTokens!.insert(key: token, self.suppliedTokens![token]! + amount)
        }

        access(contract) fun unSupplyTokens(token: Type, amount: UFix64) {
            self.suppliedTokens!.insert(key: token, self.suppliedTokens![token]! - amount)

            assert(!Lending_Borrow.checkIfBucketIsUnderCollateralized(bucket: self.uuid), message : "Undercollateralized Borrow")
        }

        access(contract) fun borrowTokens(token: Type, amount: UFix64) {
            self.borrowedTokens!.insert(key: token, self.borrowedTokens![token]! + amount)

            assert(!Lending_Borrow.checkIfBucketIsUnderCollateralized(bucket: self.uuid), message : "Undercollateralized Borrow")
        }

        access(contract) fun repayTokens(token: Type, amount: UFix64) {
            self.borrowedTokens!.insert(key: token, self.borrowedTokens![token]! - amount)
        }

        init() {
            Lending_Borrow.suppliedTokens[self.uuid] = {}
            Lending_Borrow.borrowedTokens[self.uuid] = {}
            self.suppliedTokens = &Lending_Borrow.suppliedTokens[self.uuid] as &{Type: UFix64}?
            self.borrowedTokens = &Lending_Borrow.borrowedTokens[self.uuid] as &{Type: UFix64}?
        }
    }

    pub resource Administrator {
        pub fun modifyBorrowLimitPerBucket(newLimit : UFix64) {
            Lending_Borrow.borrowLimitPerBucket = newLimit
        }

        pub fun modifySupplyTokensLimit(supplyToken: Type, limit: UFix64) {
            Lending_Borrow.supplyTokensLimit[supplyToken] = limit
        }

        pub fun modifyBorrowTokensLimit(borrowToken: Type, limit: UFix64) {
            Lending_Borrow.supplyTokensLimit[borrowToken] = limit
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

    pub fun supply(supplyTokenVault: @FungibleToken.Vault, existingLiquidityBucket: @liquidityBucket?): @liquidityBucket {
        pre {
            self.supplyTokensLimit.containsKey(supplyTokenVault.getType()): "Can't supply this token"
            supplyTokenVault.balance <= self.supplyTokensLimit[supplyTokenVault.getType()]! : "Amount greater than limit"
            supplyTokenVault.balance >= 0.0 : "Are you joking bruv"
        }
        post {
            self.totalSupplied(token: tokenVaultType) <= self.supplyTokensLimit[tokenVaultType]! : "supply exceeds limit"
        }

        let tokenVaultType = supplyTokenVault.getType()
        let supplyAmount = supplyTokenVault.balance

        self.depositToVault(token: tokenVaultType, supplyVault: <- supplyTokenVault)

        if(existingLiquidityBucket != nil) {
            let returnBucket <- existingLiquidityBucket!
            returnBucket.supplyTokens(token: tokenVaultType, amount: supplyAmount)
            return <- returnBucket
        }
        else {
            destroy existingLiquidityBucket
        }

        let newBucket <- create liquidityBucket()
        newBucket.supplyTokens(token: tokenVaultType, amount: supplyAmount)
        return <- newBucket
    }

    pub fun unsupply(bucket: &liquidityBucket, token: Type, amount: UFix64): @FungibleToken.Vault {
        pre {
            self.supplyTokensLimit.containsKey(token): "Unsupported token"
            amount >= 0.0 : "Are you joking bruv"
        }

        bucket.unSupplyTokens(token: token, amount: amount) // checks if un supplying doesn't leave bucket undercollateralized
        return <- self.withdrawFromVault(token: token, amount: amount)
    }

    pub fun borrow(bucket: &liquidityBucket, token: Type, amount: UFix64): @FungibleToken.Vault {
        pre {
            self.borrowTokensLimit.containsKey(token): "Unsupported token"
            amount >= 0.0 : "Are you joking bruv"
        }
        post {
            (self.borrowedTokens[bucket.uuid]![token]! * 100.0) / self.totalBorrowed(token: token) <= self.borrowTokensLimit[token]! : "borrow exceeds limit"
        }

        bucket.borrowTokens(token: token, amount: amount) // checks if borrowing doesn't leave bucket undercollateralized

        return <- self.withdrawFromVault(token: token, amount: amount)

    }

    pub fun repay(bucket: &liquidityBucket, tokenVault: @FungibleToken.Vault) {
        pre {
            self.borrowTokensLimit.containsKey(tokenVault.getType()): "Unsupported token"
            tokenVault.balance >= 0.0 : "Are you joking bruv"
        }

        let tokenType = tokenVault.getType()
        let tokenAmount = tokenVault.balance

        self.depositToVault(token: tokenType, supplyVault: <- tokenVault)
        bucket.repayTokens(token: tokenType, amount: tokenAmount)
    }

    pub fun checkIfBucketIsUnderCollateralized(bucket: UInt64) : Bool {
        var totalSupply = 0.0
        var totalDebt = 0.0

        self.suppliedTokens[bucket]!.forEachKey(fun (key: Type): Bool {
            totalSupply = self.suppliedTokens[bucket]![key]! + totalSupply
            return true
        })

        self.borrowedTokens[bucket]!.forEachKey(fun (key: Type): Bool {
            totalDebt = self.borrowedTokens[bucket]![key]! + totalDebt
            return true
        })

        return (totalDebt * 100.0) / totalSupply <= self.borrowLimitPerBucket
    }

    pub fun fetchPriceFromOracle(type: Type): UFix64 {
        return 1.0 // assumption of fetching from oracle
    }

    pub fun totalSupplied(token: Type): UFix64 {
        var totalSupplied = 0.0

        Lending_Borrow.suppliedTokens.forEachKey(fun (bucket: UInt64): Bool {
            
            if(Lending_Borrow.suppliedTokens[bucket]![token] != nil) {
                totalSupplied = totalSupplied + self.fetchPriceFromOracle(type: token) * Lending_Borrow.suppliedTokens[bucket]![token]!
            }

            return true
        })

        return totalSupplied 
    }

    pub fun totalBorrowed(token: Type): UFix64 {
        var totalBorrowed = 0.0

        Lending_Borrow.borrowedTokens.forEachKey(fun (bucket: UInt64): Bool {
            
            if(Lending_Borrow.borrowedTokens[bucket]![token] != nil) {
                totalBorrowed = totalBorrowed + self.fetchPriceFromOracle(type: token) * Lending_Borrow.borrowedTokens[bucket]![token]!
            }
            
            return true
        })

        return totalBorrowed
    }

    access(contract) fun depositToVault(token: Type, supplyVault: @FungibleToken.Vault) {
        var tempVault: @FungibleToken.Vault? <- self.fungibleTokenContracts[token]!.createEmptyVault()
        tempVault <-> self.tokenVaults[token]
        var finalVault <- tempVault!
        finalVault.deposit(from: <- supplyVault)
        let dumpVault <- self.tokenVaults[token] <- finalVault

        destroy dumpVault
    }

    access(contract) fun withdrawFromVault(token: Type, amount: UFix64): @FungibleToken.Vault {
        var tempVault: @FungibleToken.Vault? <- self.fungibleTokenContracts[token]!.createEmptyVault()
        tempVault <-> self.tokenVaults[token]
        var finalVault <- tempVault!
        let returnVault <- finalVault.withdraw(amount: amount)
        let dumpVault <- self.tokenVaults[token] <- finalVault
        
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
        self.fungibleTokenContracts = {}
    }

}