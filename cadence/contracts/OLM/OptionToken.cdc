import FungibleTokenOption from "../standards/FungibleTokenOption.cdc"
import FungibleToken from "../standards/FungibleToken.cdc"
import ExampleToken from "../standards/ExampleToken.cdc"
import MetadataViews from "../standards/MetadataViews.cdc"
import FungibleTokenOptionMetadataViews from "../standards/FungibleTokenOptionMetadataViews.cdc"

pub contract OptionToken: FungibleTokenOption {

    /// Total supply of OptionTokens in existence
    pub var totalSupply: UFix64

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

    /// Each user stores an instance of only the Vault in their storage
    /// The functions in the Vault and governed by the pre and post conditions
    /// in FungibleTokenOption when they are called.
    /// The checks happen at runtime whenever a function is called.
    ///
    /// Resources can only be created in the context of the contract that they
    /// are defined in, so there is no way for a malicious user to create Vaults
    /// out of thin air. A special Minter resource needs to be defined to mint
    /// new tokens.
    ///
    pub resource Vault: FungibleTokenOption.Provider, FungibleTokenOption.Receiver, FungibleTokenOption.Balance, MetadataViews.Resolver {

        /// The total balance of this vault
        pub var balance: UFix64

        pub let payoutVault: @FungibleToken.Vault

        /// Initialize the balance at resource creation time
        init(balance: UFix64, payoutVault: @FungibleToken.Vault) {
            self.balance = balance
            self.payoutVault <- (payoutVault as! @ExampleToken.Vault)
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
        pub fun withdraw(amount: UFix64): @FungibleTokenOption.Vault {
            self.balance = self.balance - amount
            emit TokensWithdrawn(amount: amount, from: self.owner?.address)
            return <-create Vault(balance: amount, payoutVault: <- (self.payoutVault.withdraw(amount: amount) as! @ExampleToken.Vault))
        }

        /// Function that takes a Vault object as an argument and adds
        /// its balance to the balance of the owners Vault.
        /// It is allowed to destroy the sent Vault because the Vault
        /// was a temporary holder of the tokens. The Vault's balance has
        /// been consumed and therefore can be destroyed.
        ///
        /// @param from: The Vault resource containing the funds that will be deposited
        ///
        pub fun deposit(from: @FungibleTokenOption.Vault) {
            let vault <- from as! @OptionToken.Vault
            self.balance = self.balance + vault.balance
            emit TokensDeposited(amount: vault.balance, to: self.owner?.address)
            vault.balance = 0.0
            destroy vault
        }

        destroy() {
            if self.balance > 0.0 {
                OptionToken.totalSupply = OptionToken.totalSupply - self.balance
            }
            destroy <- self.payoutVault
        }

        /// The way of getting all the Metadata Views implemented by OptionToken
        ///
        /// @return An array of Types defining the implemented views. This value will be used by
        ///         developers to know which parameter to pass to the resolveView() method.
        ///
        pub fun getViews(): [Type] {
            return [
                Type<FungibleTokenOptionMetadataViews.FTView>(),
                Type<FungibleTokenOptionMetadataViews.FTDisplay>(),
                Type<FungibleTokenOptionMetadataViews.FTVaultData>(),
                Type<FungibleTokenOptionMetadataViews.TotalSupply>()
            ]
        }

        /// The way of getting a Metadata View out of the OptionToken
        ///
        /// @param view: The Type of the desired view.
        /// @return A structure representing the requested view.
        ///
        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<FungibleTokenOptionMetadataViews.FTView>():
                    return FungibleTokenOptionMetadataViews.FTView(
                        ftDisplay: self.resolveView(Type<FungibleTokenOptionMetadataViews.FTDisplay>()) as! FungibleTokenOptionMetadataViews.FTDisplay?,
                        ftVaultData: self.resolveView(Type<FungibleTokenOptionMetadataViews.FTVaultData>()) as! FungibleTokenOptionMetadataViews.FTVaultData?
                    )
                case Type<FungibleTokenOptionMetadataViews.FTDisplay>():
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://assets.website-files.com/5f6294c0c7a8cdd643b1c820/5f6294c0c7a8cda55cb1c936_Flow_Wordmark.svg"
                        ),
                        mediaType: "image/svg+xml"
                    )
                    let medias = MetadataViews.Medias([media])
                    return FungibleTokenOptionMetadataViews.FTDisplay(
                        name: "Example Fungible Token",
                        symbol: "EFT",
                        description: "This fungible token is used as an example to help you develop your next FT #onFlow.",
                        externalURL: MetadataViews.ExternalURL("https://example-ft.onflow.org"),
                        logos: medias,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/flow_blockchain")
                        }
                    )
                case Type<FungibleTokenOptionMetadataViews.FTVaultData>():
                    return FungibleTokenOptionMetadataViews.FTVaultData(
                        storagePath: OptionToken.VaultStoragePath,
                        receiverPath: OptionToken.ReceiverPublicPath,
                        metadataPath: OptionToken.VaultPublicPath,
                        providerPath: /private/OptionTokenVault,
                        receiverLinkedType: Type<&OptionToken.Vault{FungibleTokenOption.Receiver}>(),
                        metadataLinkedType: Type<&OptionToken.Vault{FungibleTokenOption.Balance, MetadataViews.Resolver}>(),
                        providerLinkedType: Type<&OptionToken.Vault{FungibleTokenOption.Provider}>(),
                        createEmptyVaultFunction: (fun (): @OptionToken.Vault {
                            return <-OptionToken.createEmptyVault()
                        })
                    )
                case Type<FungibleTokenOptionMetadataViews.TotalSupply>():
                    return FungibleTokenOptionMetadataViews.TotalSupply(totalSupply: OptionToken.totalSupply)
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
        return <-create Vault(balance: 0.0, payoutVault: <- ExampleToken.createEmptyVault())
    }

    pub resource Administrator {

        /// Function that creates and returns a new minter resource
        ///
        /// @param allowedAmount: The maximum quantity of tokens that the minter could create
        /// @return The Minter resource that would allow to mint tokens
        ///
        pub fun createNewMinter(allowedAmount: UFix64): @Minter {
            emit MinterCreated(allowedAmount: allowedAmount)
            return <-create Minter(allowedAmount: allowedAmount)
        }

        /// Function that creates and returns a new burner resource
        ///
        /// @return The Burner resource
        ///
        pub fun createNewBurner(): @Burner {
            emit BurnerCreated()
            return <-create Burner()
        }
    }

    /// Resource object that token admin accounts can hold to mint new tokens.
    ///
    pub resource Minter {

        /// The amount of tokens that the minter is allowed to mint
        pub var allowedAmount: UFix64

        /// Function that mints new tokens, adds them to the total supply,
        /// and returns them to the calling context.
        ///
        /// @param amount: The quantity of tokens to mint
        /// @return The Vault resource containing the minted tokens
        ///
        pub fun mintTokens(amount: UFix64, payoutVault: @ExampleToken.Vault): @OptionToken.Vault {
            pre {
                amount > 0.0: "Amount minted must be greater than zero"
                amount <= self.allowedAmount: "Amount minted must be less than the allowed amount"
            }
            OptionToken.totalSupply = OptionToken.totalSupply + amount
            self.allowedAmount = self.allowedAmount - amount
            emit TokensMinted(amount: amount)
            return <-create Vault(balance: amount, payoutVault: <- payoutVault)
        }

        init(allowedAmount: UFix64) {
            self.allowedAmount = allowedAmount
        }
    }

    /// Resource object that token admin accounts can hold to burn tokens.
    ///
    pub resource Burner {

        /// Function that destroys a Vault instance, effectively burning the tokens.
        ///
        /// Note: the burned tokens are automatically subtracted from the
        /// total supply in the Vault destructor.
        ///
        /// @param from: The Vault resource containing the tokens to burn
        ///
        pub fun burnTokens(from: @FungibleTokenOption.Vault) {
            let vault <- from as! @OptionToken.Vault
            let amount = vault.balance
            destroy vault
            emit TokensBurned(amount: amount)
        }
    }

    init() {
        self.totalSupply = 0.0
        self.VaultStoragePath = /storage/OptionTokenVault
        self.VaultPublicPath = /public/OptionTokenMetadata
        self.ReceiverPublicPath = /public/OptionTokenReceiver
        self.AdminStoragePath = /storage/OptionTokenAdmin

        // Create the Vault with the total supply of tokens and save it in storage.
        let vault <- create Vault(balance: self.totalSupply, payoutVault: <- ExampleToken.createEmptyVault())
        self.account.save(<-vault, to: self.VaultStoragePath)

        // Create a public capability to the stored Vault that exposes
        // the `deposit` method through the `Receiver` interface.
        self.account.link<&{FungibleTokenOption.Receiver}>(
            self.ReceiverPublicPath,
            target: self.VaultStoragePath
        )

        // Create a public capability to the stored Vault that only exposes
        // the `balance` field and the `resolveView` method through the `Balance` interface
        self.account.link<&OptionToken.Vault{FungibleTokenOption.Balance}>(
            self.VaultPublicPath,
            target: self.VaultStoragePath
        )

        let admin <- create Administrator()
        self.account.save(<-admin, to: self.AdminStoragePath)

        // Emit an event that shows that the contract was initialized
        emit TokensInitialized(initialSupply: self.totalSupply)
    }
}