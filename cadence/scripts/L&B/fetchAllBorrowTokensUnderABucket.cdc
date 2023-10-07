import Lending_Borrow from "../../contracts/L&B/L&B.cdc"

pub struct tokenHoldings {
    pub let tokenId: String
    pub let amount: UFix64

    init(tokenId: String, amount: UFix64){
        self.tokenId = tokenId
        self.amount = amount
    }
}

pub fun main(bucket: UInt64): [tokenHoldings] {
    let returnArray: [tokenHoldings] = []
    
    Lending_Borrow.borrowedTokens[bucket]!.forEachKey(fun (key: String): Bool {
        let tokenId = key
        let amount = Lending_Borrow.borrowedTokens[bucket]![key]!
        returnArray.append(tokenHoldings(tokenId: tokenId, amount: amount))
        return true
    })
    return returnArray
}