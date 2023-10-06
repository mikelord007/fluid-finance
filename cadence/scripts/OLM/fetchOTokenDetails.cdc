import OptionToken from "../../contracts/OLM/OptionToken.cdc"
import FungibleToken from "../../contracts/standards/FungibleToken.cdc"

pub struct ResultStruct {
    pub let OLMToken: String
    pub let amount: UFix64
    pub let expiryTimeStamp: UFix64

    init(OLMToken: String, amount: UFix64, expiryTimeStamp: UFix64) {
        self.OLMToken = OLMToken
        self.amount = amount
        self.expiryTimeStamp = expiryTimeStamp
    }
}


pub fun main(address: Address): ResultStruct {
   let oTokenVault = getAccount(address).getCapability<&OptionToken.Vault{OptionToken.oTokenReadData,FungibleToken.Balance}>(OptionToken.VaultPublicPath).borrow()!

    //fetch amount staked
   return ResultStruct(OLMToken: OptionToken.Vault.getType().identifier, amount: oTokenVault.balance, expiryTimeStamp: oTokenVault.expiryTimeStamp)
}
// staketoken, payouttoken, rewardRate