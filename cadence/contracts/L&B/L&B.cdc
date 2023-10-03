import FungibleToken from "../standards/FungibleToken.cdc"

pub contract Lending_Borrow {
    pub var totalLiquidity: UFix64
    pub var totalDebt: UFix64
    pub var debtLimitPerTicket: UFix64
    pub let supplyTokensLimit : {Type : UFix64} // Type of Token : Hard Upper limit on amount of tokens
    pub let borrowTokensLimit : {Type : UFix64} // Type of Token : Percentage of max borrowable from pool

    pub let tokenVaults: @{Type: FungibleToken.Vault}
    pub let fungibleTokenRef: {Type: FungibleToken}
 
    pub resource liquidityBucket {
        pub let suppliedTokens : &{Type: UFix64}
        pub let debtTokens: &{Type: UFix64}

        access(contract) fun suppliedMoreTokens(token: Type, amount: UFix64) {

            self.suppliedTokens[token] = self.suppliedTokens[token] != nil ? self.suppliedTokens[token]!  + amount : amount
        }

        access(contract) fun borrowedMoreTokens(token: Type, amount: UFix64) {

            self.debtTokens[token] = self.debtTokens[token] != nil ? self.debtTokens[token]!  + amount : amount
        }

        init() {
            self.suppliedTokens = {}
            self.debtTokens = {}
        }
    }

    pub resource Administrator {
        pub fun modifyTicketDebtLimit() {}

        pub fun setupBorrowTokens() {}

        pub fun setupSupplyTokens() {}

        pub fun liquidateUnderCollateralizedPositions() {}
    }

    pub fun supply(supplyTokenVault: @FungibleToken.Vault, existingLiquidityBucket: @liquidityBucket?): @liquidityBucket {
        pre {
            self.supplyTokensLimit.containsKey(supplyTokenVault.getType()): "Can't supply this token"
            supplyTokenVault.balance <= self.supplyTokensLimit[supplyTokenVault.getType()]! : "Amount greater than limit"
            supplyTokenVault.balance >= 0.0 : "Are you joking bruv"
        }

        let tokenVaultType = supplyTokenVault.getType()
        let supplyAmount = supplyTokenVault.balance

        self.totalLiquidity = self.totalLiquidity + supplyTokenVault.balance
        
        var tempVault: @FungibleToken.Vault? <- self.fungibleTokenRef[supplyTokenVault.getType()]!.createEmptyVault()
        tempVault <-> self.tokenVaults[tokenVaultType]
        var finalVault <- tempVault!
        finalVault.deposit(from: <- supplyTokenVault)
        let dumpVault <- self.tokenVaults[tokenVaultType] <- finalVault
        
        destroy dumpVault

        let price = self.fetchPrice(type: tokenVaultType)
        let totalSuppliedPrice = price * supplyAmount

        if(existingLiquidityBucket != nil) {
            let returnBucket <- existingLiquidityBucket as! @liquidityBucket
            returnBucket.suppliedMoreTokens(token: tokenVaultType, amount: supplyAmount)
            return <- returnBucket
        }
        else {
            destroy existingLiquidityBucket
        }

        let newBucket <- create liquidityBucket()
        newBucket.suppliedMoreTokens(token: tokenVaultType, amount: supplyAmount)
        return <- newBucket
    }

    pub fun unsupply(existingLiquidityBucket: @liquidityBucket): @liquidityBucket? {
        destroy existingLiquidityBucket
        return nil
    }

    pub fun claimRewards() {}

    pub fun borrow() {}

    pub fun repay() {}

    pub fun fetchPrice(type: Type): UFix64 {
        return 10.0
    }

    init() {
        self.totalLiquidity = 0.0
        self.totalDebt = 0.0
        self.debtLimitPerTicket = 80.00
        self.borrowTokensLimit = {}
        self.supplyTokensLimit = {}
        self.tokenVaults <- {}
        self.fungibleTokenRef = {}
    }

}