#!/bin/sh

claims_file=./setup/ClaimList.t.sol
claims_amount=100
users_amount=100

random_int() {
  # 2^ 64 - 2 , max range for shuf, == 18e18, not ideal.
  echo "$(shuf  -n 1 -i 0-18446744073709551614)"
}

cat - > "$claims_file" <<EOF
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

contract ClaimsList {
    struct ClaimEntry {
        address recipient;
        uint256 ethAmount;
        uint256 daiAmount;
        uint256 gtcAmount;
        uint256 usdtAmount;
        uint256 usdcAmount;
    }

    ClaimEntry[] internal randomClaims;

    constructor() {
        // ensure at least one all-zero claim
        randomClaims.push(ClaimEntry(0x0000000000000000000000000000000000010000, 0, 0, 0, 0, 0));
        // one  zero-erc20 claim
        randomClaims.push(ClaimEntry(0x0000000000000000000000000000000000020000, 1e18, 0, 0, 0, 0));
        // one  zero-eth claim
        randomClaims.push(ClaimEntry(0x0000000000000000000000000000000000030000, 0, 100e18, 0, 0, 0));
        // remaining randomly-generated claims
EOF
for i in  $(seq "$claims_amount") ; do
  # have some overlap with medusa's actors
  recipient="address($(shuf -n 1 -i 1-${users_amount}) << 16)";
  ethAmount=$(random_int)
  daiAmount=$(random_int)
  gtcAmount=$(random_int)
  usdtAmount=$(random_int)
  usdcAmount=$(random_int)
  echo "        randomClaims.push(ClaimEntry($recipient, $ethAmount, $daiAmount, $gtcAmount, $usdtAmount, $usdcAmount));" >> "$claims_file"

done


cat - >> "$claims_file" <<EOF
    }
}
EOF
forge fmt "$claims_file"
