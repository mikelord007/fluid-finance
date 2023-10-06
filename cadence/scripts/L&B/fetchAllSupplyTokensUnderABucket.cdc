import Lending_Borrow from "../../contracts/L&B/L&B.cdc"

pub fun main(bucket: UInt64): {String: UFix64} {

    return Lending_Borrow.suppliedTokens[bucket]!
}