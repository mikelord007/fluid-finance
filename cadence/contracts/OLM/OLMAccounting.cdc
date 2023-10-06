import FungibleToken from "../standards/FungibleToken.cdc"
import ExampleToken from "../standards/ExampleToken.cdc"
import OptionToken from "./OptionToken.cdc"

pub contract OLMAccounting {
 
    pub event NewEpoch(epoch_: UInt32, optionToken_: String)

    pub var stakedTokenVaultType: String? 
    pub var payoutTokenVaultType: String? 
    pub var buyWithTokenVaultType: String?
    pub let stakeAccountingKeyStoragePath: StoragePath
    pub let stakeAccountingKeyPublicPath: PublicPath
    pub let AdminStoragePath: StoragePath
    pub var timeToExpireOtokens: UFix64
 
    pub var stakeVault: @FungibleToken.Vault?
    pub var payoutVault: @FungibleToken.Vault?

    pub var optionMinter : @OptionToken.Minter?

    pub var rewardRate: UInt64

    pub resource interface readStakeKeyDetails {
        pub let amount: UFix64
    }
    //stakeAccountingKey can be used to unstake or claim rewards
    pub resource stakeAccountingKey: readStakeKeyDetails {
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

        pub fun initialize(stakedTokenvaultType_: String, payoutTokenVaultType_: String, buyWithTokenVaultType_: String,
         stakedTokenContract_: &FungibleToken, payoutTokenContract_: &FungibleToken, rewardRate_: UInt64,
         optionMinter_: @OptionToken.Minter, timeToExpire: UFix64) {

            OLMAccounting.stakedTokenVaultType = stakedTokenvaultType_
            OLMAccounting.payoutTokenVaultType = payoutTokenVaultType_
            OLMAccounting.buyWithTokenVaultType = buyWithTokenVaultType_
            OLMAccounting.rewardRate = rewardRate_
            OLMAccounting.optionMinter <-! optionMinter_
            OLMAccounting.timeToExpireOtokens = timeToExpire

            var tempVault: @FungibleToken.Vault <- stakedTokenContract_.createEmptyVault()
            assert(tempVault.getType().identifier == stakedTokenvaultType_, message: "Wrong Staked Token Vault Type")
            OLMAccounting.stakeVault <-! tempVault

            let tempPayoutVault <- payoutTokenContract_.createEmptyVault()
            assert(tempPayoutVault.getType().identifier == stakedTokenvaultType_, message: "Wrong Payout Token Vault Type")
            OLMAccounting.payoutVault <-! tempPayoutVault
        }
    }

    pub fun depositPayout(payoutVault: @FungibleToken.Vault)  {
        pre {
            payoutVault.getType().identifier == self.payoutTokenVaultType : "Wrong Payout Token Vault Type"
        }

        let tempVault: @FungibleToken.Vault? <- self.payoutVault <- nil

        let selfVault <- tempVault!
        
        selfVault.deposit(from: <- payoutVault)
        
        self.payoutVault <-! selfVault
        
    }

    pub fun stake(stakeTokenVault: @FungibleToken.Vault): @stakeAccountingKey {
        pre {
            stakeTokenVault.getType().identifier == self.stakedTokenVaultType : "Wrong Vault Sent"
            stakeTokenVault.balance == 0.0 : "Bruh"
        }

        let balance = stakeTokenVault.balance
        let tempVault <- self.stakeVault <- nil
        let stakeVault <- tempVault!
        stakeVault.deposit(from: <- stakeTokenVault)
        self.stakeVault <-! stakeVault

        return <- create stakeAccountingKey(amount: balance)
    }

    pub fun unstake(stakeKey: @stakeAccountingKey): @FungibleToken.Vault {
        let tempVault <- self.stakeVault <- nil
        let stakedVault <- tempVault!
        let returnVault <- stakedVault.withdraw(amount: stakeKey.amount)
        
        self.stakeVault <-! stakedVault
        destroy stakeKey

        return <- returnVault
    }

    pub fun claimRewardsTillNow(stakeKey: &stakeAccountingKey): @OptionToken.Vault {
        let time = UInt64(getCurrentBlock().timestamp - stakeKey.lastClaimedReward)
        let rewardAmount = time * UInt64(stakeKey.amount) * self.rewardRate
        
        let tempPayoutVault <- self.payoutVault <- nil
        let payoutVault <- tempPayoutVault!
        let withdrawenVault <- payoutVault.withdraw(amount: UFix64(rewardAmount))
        self.payoutVault <-! payoutVault

        let tempMinter <- self.optionMinter <- nil
        let minter <- tempMinter!

        let amountToBuyWith = self.fetchDiscountedPriceFromOracle(type: self.payoutTokenVaultType!)
        let totalAmount = UFix64(rewardAmount) * amountToBuyWith

        let expiryTimestamp = getCurrentBlock().timestamp + self.timeToExpireOtokens

        let oTokens <- minter.mintTokens(amount: UFix64(rewardAmount), payoutVault: <- (withdrawenVault as! @ExampleToken.Vault),
        buyWithTokenType: self.buyWithTokenVaultType!, amountOfBuyWith: totalAmount, expiryTime: expiryTimestamp)

        self.optionMinter <-! minter
        stakeKey.setLastClaimedReward(time: getCurrentBlock().timestamp) 

        return <- oTokens
    }

    pub fun fetchDiscountedPriceFromOracle(type: String): UFix64 {
        return 100.0 // assume call to oracle
    }

    init() {

        self.AdminStoragePath = /storage/OLMAccountingAdmin

        self.stakedTokenVaultType = nil
        self.payoutTokenVaultType = nil
        self.buyWithTokenVaultType = nil
        self.stakeAccountingKeyStoragePath = /storage/stakeAccountingKey
        self.stakeAccountingKeyPublicPath = /public/stakeAccountingKey
        self.rewardRate = 0
        self.optionMinter <- nil
        self.stakeVault <- nil
        self.payoutVault <- nil
        self.timeToExpireOtokens = 0.0

        let admin <- create Administrator()
        self.account.save(<-admin, to: self.AdminStoragePath)
    }

}