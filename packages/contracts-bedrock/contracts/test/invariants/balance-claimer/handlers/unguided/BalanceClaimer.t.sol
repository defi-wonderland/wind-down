// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {BalanceClaimerSetup} from '../../setup/BalanceClaimer.t.sol';

contract BalanceClaimerUnguidedHandlers is BalanceClaimerSetup {
  /// @custom:property-id
  /// @custom:property
  function handler_fooUnguided(address _caller, string memory _newGreeting) external {
  }
}
