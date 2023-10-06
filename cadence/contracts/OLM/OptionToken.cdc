import FungibleToken from "../standards/FungibleToken.cdc"
import ExampleToken from "../standards/ExampleToken.cdc"
import MetadataViews from "../standards/MetadataViews.cdc"
import FungibleTokenMetadataViews from "../standards/FungibleTokenMetadataViews.cdc"

pub contract OptionToken: FungibleToken {

    /// Total supply of OptionTokens in existence
    pub var totalSupply: UFix64

    pub var buyWithVault: @FungibleToken.Vault?

    /// Storage and Public Paths
    pub let VaultStoragePath: StoragePath
    pub let VaultPublicPath: PublicPath
    pub let ReceiverPublicPath: PublicPath
    pub let AdminStoragePath: StoragePath

    /// The event that is emitted when the contract is created
    pub event TokensInitialized(initialSupply: UFix64)

    /// The event that is emitted when tokens are withdrawn from a Vault
    pub event TokensWithdrawn(amount: UFix64, from: Address?)

    /// The event that is emitted when tokens are deposited to a Vault
    pub event TokensDeposited(amount: UFix64, to: Address?)

    /// The event that is emitted when new tokens are minted
    pub event TokensMinted(amount: UFix64)

    /// The event that is emitted when tokens are destroyed
    pub event TokensBurned(amount: UFix64)

    /// The event that is emitted when a new minter resource is created
    pub event MinterCreated(allowedAmount: UFix64)

    /// The event that is emitted when a new burner resource is created
    pub event BurnerCreated()

    pub resource interface oTokenReadData {
        pub var expiryTimeStamp: UFix64
    }
    /// Each user stores an instance of only the Vault in their storage
    /// The functions in the Vault and governed by the pre and post conditions
    /// in FungibleToken when they are called.
    /// The checks happen at runtime whenever a function is called.
    ///
    /// Resources can only be created in the context of the contract that they
    /// are defined in, so there is no way for a malicious user to create Vaults
    /// out of thin air. A special Minter resource needs to be defined to mint
    /// new tokens.
    ///
    pub resource Vault: FungibleToken.Provider, FungibleToken.Receiver, FungibleToken.Balance, MetadataViews.Resolver, oTokenReadData {

        /// The total balance of this vault
        pub var balance: UFix64

        pub var payoutVault: @ExampleToken.Vault

        pub var buyWithTokenType: String // buyWith Token Identifier
        pub var amountOfBuyWith: UFix64

        pub var initialized: Bool
        pub var expiryTimeStamp: UFix64 // timestamp rounded to days

        init(balance: UFix64) {
            self.balance = balance
            self.payoutVault <- ExampleToken.createEmptyVault()
            self.expiryTimeStamp = 0.0
            self.initialized = false
            self.buyWithTokenType = ""
            self.amountOfBuyWith = 0.0
        }

        access(contract) fun initialize(buyWithTokenType: String, amountOfBuyWith: UFix64, expiryTime: UFix64) {
            pre {
                !self.initialized : "already initalized"
            }
            self.initialized = true
            self.expiryTimeStamp = expiryTime
            self.buyWithTokenType = buyWithTokenType
            self.amountOfBuyWith = amountOfBuyWith
        }

        access(contract) fun redeemTokens(buyWithVault: @FungibleToken.Vault): @ExampleToken.Vault {
            pre {
                buyWithVault.getType().identifier == self.buyWithTokenType : "Wrong Vault Sent"
                buyWithVault.balance == self.amountOfBuyWith : "Wrong amount"
            }
            
            let tempVault <- OptionToken.buyWithVault <- nil
            let depositVault <- tempVault!
            depositVault.deposit(from: <- buyWithVault)
            OptionToken.buyWithVault <-! depositVault

            let returnVault <- self.payoutVault <- ExampleToken.createEmptyVault()
            return <- returnVault
        }

        /// Function that takes an amount as an argument
        /// and withdraws that amount from the Vault.
        /// It creates a new temporary Vault that is used to hold
        /// the money that is being transferred. It returns the newly
        /// created Vault to the context that called so it can be deposited
        /// elsewhere.
        ///
        /// @param amount: The amount of tokens to be withdrawn from the vault
        /// @return The Vault resource containing the withdrawn funds
        ///
        pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
            post {
                self.balance == self.payoutVault.balance
            }
            self.balance = self.balance - amount
            emit TokensWithdrawn(amount: amount, from: self.owner?.address)
            let vault <-create Vault(balance: amount)
            let vaultAmountBuyWith = (self.amountOfBuyWith * amount )/ self.balance
            vault.initialize(buyWithTokenType: self.buyWithTokenType, amountOfBuyWith: vaultAmountBuyWith, expiryTime: self.expiryTimeStamp)
            vault.payoutVault.deposit(from: <- self.payoutVault.withdraw(amount: amount))

            assert(vault.balance == vault.payoutVault.balance)
            return <- vault
        }

        /// Function that takes a Vault object as an argument and adds
        /// its balance to the balance of the owners Vault.
        /// It is allowed to destroy the sent Vault because the Vault
        /// was a temporary holder of the tokens. The Vault's balance has
        /// been consumed and therefore can be destroyed.
        ///
        /// @param from: The Vault resource containing the funds that will be deposited
        ///
        pub fun deposit(from: @FungibleToken.Vault) {
            post {
                self.balance == self.payoutVault.balance
            }

            let vault <- from as! @OptionToken.Vault

            assert(self.buyWithTokenType == vault.buyWithTokenType)
            assert(self.expiryTimeStamp == vault.expiryTimeStamp)
                
            self.balance = self.balance + vault.balance 
            self.amountOfBuyWith = self.amountOfBuyWith + vault.amountOfBuyWith
            self.payoutVault.deposit(from: <- vault.payoutVault.withdraw(amount: vault.balance))

            emit TokensDeposited(amount: vault.balance, to: self.owner?.address)
            vault.balance = 0.0
            destroy vault
        }

        destroy() {
            if self.balance > 0.0 {
                OptionToken.totalSupply = OptionToken.totalSupply - self.balance
            }

            destroy self.payoutVault
        }

        /// The way of getting all the Metadata Views implemented by OptionToken
        ///
        /// @return An array of Types defining the implemented views. This value will be used by
        ///         developers to know which parameter to pass to the resolveView() method.
        ///
        pub fun getViews(): [Type] {
            return [
                Type<FungibleTokenMetadataViews.FTView>(),
                Type<FungibleTokenMetadataViews.FTDisplay>(),
                Type<FungibleTokenMetadataViews.FTVaultData>(),
                Type<FungibleTokenMetadataViews.TotalSupply>()
            ]
        }

        /// The way of getting a Metadata View out of the OptionToken
        ///
        /// @param view: The Type of the desired view.
        /// @return A structure representing the requested view.
        ///
        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<FungibleTokenMetadataViews.FTView>():
                    return FungibleTokenMetadataViews.FTView(
                        ftDisplay: self.resolveView(Type<FungibleTokenMetadataViews.FTDisplay>()) as! FungibleTokenMetadataViews.FTDisplay?,
                        ftVaultData: self.resolveView(Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
                    )
                case Type<FungibleTokenMetadataViews.FTDisplay>():
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://assets.website-files.com/5f6294c0c7a8cdd643b1c820/5f6294c0c7a8cda55cb1c936_Flow_Wordmark.svg"
                        ),
                        mediaType: "image/svg+xml"
                    )
                    let medias = MetadataViews.Medias([media])
                    return FungibleTokenMetadataViews.FTDisplay(
                        name: "Example Fungible Token",
                        symbol: "EFT",
                        description: "This fungible token is used as an example to help you develop your next FT #onFlow.",
                        externalURL: MetadataViews.ExternalURL("https://example-ft.onflow.org"),
                        logos: medias,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/flow_blockchain")
                        }
                    )
                case Type<FungibleTokenMetadataViews.FTVaultData>():
                    return FungibleTokenMetadataViews.FTVaultData(
                        storagePath: OptionToken.VaultStoragePath,
                        receiverPath: OptionToken.ReceiverPublicPath,
                        metadataPath: OptionToken.VaultPublicPath,
                        providerPath: /private/OptionTokenVault,
                        receiverLinkedType: Type<&OptionToken.Vault{FungibleToken.Receiver}>(),
                        metadataLinkedType: Type<&OptionToken.Vault{FungibleToken.Balance, MetadataViews.Resolver}>(),
                        providerLinkedType: Type<&OptionToken.Vault{FungibleToken.Provider}>(),
                        createEmptyVaultFunction: (fun (): @FungibleToken.Vault {
                            return <-OptionToken.createEmptyVault()
                        })
                    )
                case Type<FungibleTokenMetadataViews.TotalSupply>():
                    return FungibleTokenMetadataViews.TotalSupply(totalSupply: OptionToken.totalSupply)
            }
            return nil
        }
    }

    /// Function that creates a new Vault with a balance of zero
    /// and returns it to the calling context. A user must call this function
    /// and store the returned Vault in their storage in order to allow their
    /// account to be able to receive deposits of this token type.
    ///
    /// @return The new Vault resource
    ///
    pub fun createEmptyVault(): @Vault {
        panic("not allowed")
    }

    /// Resource object that token admin accounts can hold to mint new tokens.
    ///
    pub resource Minter {

        /// Function that mints new tokens, adds them to the total supply,
        /// and returns them to the calling context.
        ///
        /// @param amount: The quantity of tokens to mint
        /// @return The Vault resource containing the minted tokens
        ///
        pub fun mintTokens(amount: UFix64, payoutVault: @ExampleToken.Vault, buyWithTokenType: String,
         amountOfBuyWith: UFix64, expiryTime: UFix64): @OptionToken.Vault {
            pre {
                amount > 0.0: "Amount minted must be greater than zero"
                payoutVault.balance == amount : "Incorrect payoutVault Balance"
            }
            post {
                result.balance == result.payoutVault.balance : "Unbalanced Vault"
            }

            OptionToken.totalSupply = OptionToken.totalSupply + amount
            emit TokensMinted(amount: amount)
            let vault <- create Vault(balance: amount)
            vault.initialize(buyWithTokenType: buyWithTokenType, amountOfBuyWith: amountOfBuyWith, expiryTime: expiryTime)
            vault.payoutVault.deposit(from: <- payoutVault)      
            
            return <- vault
        }
    }
    
    pub fun redeemPayoutTokens(oToken: @OptionToken.Vault, buyWithVault: @FungibleToken.Vault): @ExampleToken.Vault {
        pre {
            getCurrentBlock().timestamp < oToken.expiryTimeStamp : "expired tokens"
        }

        let returnVault <- oToken.redeemTokens(buyWithVault: <- buyWithVault)
        destroy oToken
        return <- returnVault
    }

    init() {
        self.totalSupply = 0.0
        self.buyWithVault <- nil
        self.VaultStoragePath = /storage/OptionTokenVault
        self.VaultPublicPath = /public/OptionTokenMetadata
        self.ReceiverPublicPath = /public/OptionTokenReceiver
        self.AdminStoragePath = /storage/OptionTokenAdmin

        // Create a public capability to the stored Vault that exposes
        // the `deposit` method through the `Receiver` interface.
        self.account.link<&{FungibleToken.Receiver}>(
            self.ReceiverPublicPath,
            target: self.VaultStoragePath
        )

        // Create a public capability to the stored Vault that only exposes
        // the `balance` field and the `resolveView` method through the `Balance` interface
        self.account.link<&OptionToken.Vault{FungibleToken.Balance}>(
            self.VaultPublicPath,
            target: self.VaultStoragePath
        )

        // Emit an event that shows that the contract was initialized
        emit TokensInitialized(initialSupply: self.totalSupply)
    }
    
}