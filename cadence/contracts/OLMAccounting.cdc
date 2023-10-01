import FungibleToken from "./standards/FungibleToken.cdc"
import OptionToken from "./OptionToken.cdc"

pub contract OLMAccounting {
 
    pub event NewEpoch(epoch_: UInt32, optionToken_: String)

    pub let stakedTokenVaultType: Type 
    pub let payoutTokenVaultType: Type 
    pub let buyWithTokenVaultType: Type
    pub let stakeAccountingKeyStoragePath: StoragePath
    pub let AdminStoragePath: StoragePath
 
    pub let stakeVault: @FungibleToken.Vault
    pub let payoutVault: @FungibleToken.Vault

    pub let optionMinter : @OptionToken.Minter

    pub var rewardRate: UInt64

    //stakeAccountingKey can be used to unstake or claim rewards
    pub resource stakeAccountingKey {
        pub let amount: UFix64
        pub var lastClaimedReward: UFix64

        access(contract) fun setLastClaimedReward(time: UFix64) {
            self.lastClaimedReward = time
        }

        init(amount: UFix64){
            self.amount = amount
            self.lastClaimedReward = getCurrentBlock().timestamp
        }
    }

    pub resource Administrator {
        pub fun setRewardRate(newRate: UInt64) {
            OLMAccounting.rewardRate = newRate
        }
    }

    init(stakedTokenvaultType_: Type, payoutTokenVaultType_: Type, buyWithTokenVaultType_: Type,
         stakedTokenContract_: &FungibleToken, payoutTokenContract_: &FungibleToken, rewardRate_: UInt64,
         optionMinter_: @OptionToken.Minter) {

        self.AdminStoragePath = /storage/OLMAccountingAdmin

        self.stakedTokenVaultType = stakedTokenvaultType_
        self.payoutTokenVaultType = payoutTokenVaultType_
        self.buyWithTokenVaultType = buyWithTokenVaultType_
        self.stakeAccountingKeyStoragePath = /storage/stakeAccountingKey
        self.rewardRate = rewardRate_
        self.optionMinter <- optionMinter_

        var tempVault: @FungibleToken.Vault <- stakedTokenContract_.createEmptyVault()
        assert(tempVault.getType() == stakedTokenvaultType_, message: "Wrong Staked Token Vault Type")
        self.stakeVault <- tempVault

        let tempPayoutVault <- payoutTokenContract_.createEmptyVault()
        assert(tempPayoutVault.getType() == stakedTokenvaultType_, message: "Wrong Payout Token Vault Type")
        self.payoutVault <- tempPayoutVault

        let admin <- create Administrator()
        self.account.save(<-admin, to: self.AdminStoragePath)
    }

    pub fun depositPayout(payoutVault: @FungibleToken.Vault) {
        pre {
            payoutVault.getType() == self.payoutTokenVaultType : "Wrong Payout Token Vault Type"
        }

        self.payoutVault.deposit(from: <- payoutVault)
    }

    pub fun stake(stakeTokenVault: @FungibleToken.Vault): @stakeAccountingKey {
        pre {
            stakeTokenVault.getType() == self.stakedTokenVaultType : "Wrong Vault Sent"
            stakeTokenVault.balance == 0.0 : "Bruh"
        }

        let balance = stakeTokenVault.balance
        self.stakeVault.deposit(from: <- stakeTokenVault)

        return <- create stakeAccountingKey(amount: balance)
    }

    pub fun unstake(stakeKey: @stakeAccountingKey): @FungibleToken.Vault {
        
        let stakedVault <- self.stakeVault.withdraw(amount: stakeKey.amount)
        destroy stakeKey

        return <- stakedVault
    }

    pub fun claimRewardsTillNow(stakeKey: &stakeAccountingKey): @OptionToken.Vault {
        let time = UInt64(getCurrentBlock().timestamp - stakeKey.lastClaimedReward)

        let rewardAmount = time * UInt64(stakeKey.amount) * self.rewardRate

        let oTokens <- self.optionMinter.mintTokens(amount: UFix64(rewardAmount), payoutVault: <- self.payoutVault.withdraw(amount: rewardAmount))

        stakeKey.setLastClaimedReward(time: getCurrentBlock().timestamp)

        return <- oTokens
    }

}