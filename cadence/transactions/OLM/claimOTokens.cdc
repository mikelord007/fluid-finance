import OLMAccounting from "../../contracts/OLM/OLMAccounting.cdc"
import OptionToken from "../../contracts/OLM/OptionToken.cdc"
import FungibleToken from "../../contracts/standards/FungibleToken.cdc"

transaction() {
    prepare(accnt: AuthAccount) {

        let stakeKey = accnt.borrow<&OLMAccounting.stakeAccountingKey>(from: OLMAccounting.stakeAccountingKeyStoragePath)!
        let oTokenVault <- OLMAccounting.claimRewardsTillNow(stakeKey: stakeKey)
        
        let oVault = accnt.borrow<&OptionToken.Vault>(from: OptionToken.VaultStoragePath)

        if(oVault == nil) {
            accnt.save(<- oTokenVault, to: OptionToken.VaultStoragePath)
        }
        else {
            oVault!.deposit(from: <- oTokenVault)
        }
    }
}