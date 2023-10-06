import OLMAccounting from "../../contracts/OLM/OLMAccounting.cdc"

pub struct ResultStruct {
    pub let stakeToken: String
    pub let amountStaked: UFix64

    init(stakeToken: String, amountStaked: UFix64) {
        self.stakeToken = stakeToken
        self.amountStaked = amountStaked
    }
}


pub fun main(address: Address): ResultStruct {
   let stakeKey = getAccount(address).getCapability<&OLMAccounting.stakeAccountingKey{OLMAccounting.readStakeKeyDetails}>(OLMAccounting.stakeAccountingKeyPublicPath).borrow()!

    //fetch amount staked
   return ResultStruct(stakeToken: OLMAccounting.stakedTokenVaultType!, amountStaked: stakeKey.amount)
}
// staketoken, payouttoken, rewardRate