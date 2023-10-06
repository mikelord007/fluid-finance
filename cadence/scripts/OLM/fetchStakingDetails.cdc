import OLMAccounting from "../../contracts/OLM/OLMAccounting.cdc"

pub struct ResultStruct {
    pub let stakeToken: String
    pub let payoutToken: String
    pub let rewardRate: UInt64

    init(stakeToken: String, payoutToken: String, rewardRate: UInt64) {
        self.stakeToken = stakeToken
        self.payoutToken = payoutToken
        self.rewardRate = rewardRate
    }
}


pub fun main(): ResultStruct {
   return ResultStruct(stakeToken: OLMAccounting.stakedTokenVaultType!, payoutToken: OLMAccounting.payoutTokenVaultType!, rewardRate: OLMAccounting.rewardRate)
}
// staketoken, payouttoken, rewardRate