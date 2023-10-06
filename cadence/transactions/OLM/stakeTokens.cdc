import OLMAccounting from "../../contracts/OLM/OLMAccounting.cdc"
import FungibleToken from "../../contracts/standards/FungibleToken.cdc"
import StakeToken from "../../contracts/standards/StakeToken.cdc"

transaction(amount: UFix64) {
    prepare(accnt: AuthAccount) {

        let vault = accnt.borrow<&FungibleToken.Vault>(from: StakeToken.VaultStoragePath)!

        let stakeAccountingKey <- OLMAccounting.stake(stakeTokenVault: <- vault.withdraw(amount: amount))
        accnt.save(<- stakeAccountingKey, to: OLMAccounting.stakeAccountingKeyStoragePath)
        accnt.link<&OLMAccounting.stakeAccountingKey{OLMAccounting.readStakeKeyDetails}>(OLMAccounting.stakeAccountingKeyPublicPath, target: OLMAccounting.stakeAccountingKeyStoragePath)

    }
}