import OLMAccounting from "../../contracts/OLM/OLMAccounting.cdc"
import FungibleToken from "../../contracts/standards/FungibleToken.cdc"
import ExampleToken from "../../contracts/standards/ExampleToken.cdc"

transaction() {
    prepare(accnt: AuthAccount) {

        let vault = accnt.borrow<&FungibleToken.Vault>(from: ExampleToken.VaultStoragePath)!
        let stakeKey <- accnt.load<@OLMAccounting.stakeAccountingKey>(from: OLMAccounting.stakeAccountingKeyStoragePath)!
        let newVault <- OLMAccounting.unstake(stakeKey: <- stakeKey)

        vault.deposit(from: <- newVault)

    }
}