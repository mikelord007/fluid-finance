import OptionToken from "../../contracts/OLM/OptionToken.cdc"
import FungibleToken from "../../contracts/standards/FungibleToken.cdc"
import BuyWithToken from "../../contracts/standards/BuyWithToken.cdc"
import PayoutToken from "../../contracts/standards/PayoutToken.cdc"

transaction() {
    prepare(accnt: AuthAccount) {

        let optionVault <- accnt.load<@OptionToken.Vault>(from: OptionToken.VaultStoragePath)!
        let buyWithVault = accnt.borrow<&BuyWithToken.Vault>(from: BuyWithToken.VaultStoragePath)!
        let amountofBuyWith = optionVault.amountOfBuyWith
        let payoutTokenVault <- OptionToken.redeemPayoutTokens(oToken: <- optionVault, buyWithVault: <- buyWithVault.withdraw(amount: amountofBuyWith))
        accnt.save(<- payoutTokenVault, to: PayoutToken.VaultStoragePath)

    }
}