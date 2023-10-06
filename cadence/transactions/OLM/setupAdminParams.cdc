//fetch minter
//call initialize
//fund w/ payoutimport Lending_Borrow from "../../contracts/L&B/L&B.cdc"
import OLMAccounting from "../../contracts/OLM/OLMAccounting.cdc"
import OptionToken from "../../contracts/OLM/OptionToken.cdc"
import FungibleToken from "../../contracts/standards/FungibleToken.cdc"
import PayoutToken from "../../contracts/standards/PayoutToken.cdc"
import BuyWithToken from "../../contracts/standards/BuyWithToken.cdc"
import StakeToken from "../../contracts/standards/StakeToken.cdc"

transaction() {
    prepare(adminAccount: AuthAccount) {
        let minter <- OptionToken.createMinter()
        adminAccount.save(<- minter, to: OptionToken.MinterStoragePath)
        let admin <- OLMAccounting.createAdmin()
        adminAccount.save(<- admin, to: OLMAccounting.AdminStoragePath)

        let minterRes <- adminAccount.load<@OptionToken.Minter>(from: OptionToken.MinterStoragePath)!
        let adminRef = adminAccount.borrow<&OLMAccounting.Administrator>(from: OLMAccounting.AdminStoragePath) 

        let stakeVault <- StakeToken.createEmptyVault()
        let stakeVaultType = stakeVault.getType().identifier
        destroy stakeVault

        let payoutVault <- PayoutToken.createEmptyVault()
        let payoutVaultType = payoutVault.getType().identifier
        destroy payoutVault

        let buyWithVault <- BuyWithToken.createEmptyVault()
        let buyWithVaultType = buyWithVault.getType().identifier
        destroy buyWithVault
        
        adminRef!.initialize(stakedTokenvaultType_: stakeVaultType, payoutTokenVaultType_: payoutVaultType, buyWithTokenVaultType_: buyWithVaultType, stakedTokenContract_: &StakeToken as &FungibleToken, payoutTokenContract_: &PayoutToken as &FungibleToken, rewardRate_: 1, optionMinter_: <- minterRes, timeToExpire: 1000000.00)

        OLMAccounting.depositPayout(payoutVault: <- PayoutToken.mintTokens(amount: 100000000.0))
    }
}