// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/console.sol";

import {BalanceClaimer} from "contracts/L1/winddown/BalanceClaimer.sol";
import {OptimismPortal} from "contracts/L1/OptimismPortal.sol";
import {L1StandardBridge} from "contracts/L1/L1StandardBridge.sol";
import {L1ChugSplashProxy} from "contracts/legacy/L1ChugSplashProxy.sol";
import {L2OutputOracle} from "contracts/L1/L2OutputOracle.sol";
import {SystemConfig} from "contracts/L1/SystemConfig.sol";
import {Proxy} from "contracts/universal/Proxy.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";

import {CommonBase} from "forge-std/Base.sol";


contract FuzzERC20 is MockERC20 {
    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }
}

contract BalanceClaimerSetup is CommonBase{
    uint256 internal constant INITIAL_BALANCE = 100000e18;
    L1StandardBridge internal l1StandardBridge;
    OptimismPortal internal optimismPortal;
    BalanceClaimer internal balanceClaimer;
    IERC20[] internal supportedTokens;

    constructor() {
        Proxy balanceClaimerProxy = new Proxy(address(this));

        L1StandardBridge l1StandardBridgeImpl = new L1StandardBridge(payable(0), payable(address(balanceClaimerProxy)));
        OptimismPortal optimismPortalImpl = new OptimismPortal({
            _l2Oracle: L2OutputOracle(address(0)),
            _guardian: address(0),
            _paused: false,
            _config: SystemConfig(address(0)),
            _balanceClaimer: address(balanceClaimerProxy)
        });
        // Get the proxies for L1StandardBridge and OptimismPortal
        L1ChugSplashProxy l1StandardBridgeProxy = new L1ChugSplashProxy(address(this));
        Proxy optimismPortalProxy = new Proxy(address(this));

        BalanceClaimer balanceClaimerImpl = new BalanceClaimer();

        // Set BalanceClaimer implementation
        balanceClaimerProxy.upgradeToAndCall(
            address(balanceClaimerImpl),
            abi.encodeWithSelector(
                balanceClaimerImpl.initialize.selector,
                address(optimismPortalProxy),
                address(l1StandardBridgeProxy),
                bytes32(0)
            )
        );
        optimismPortalProxy.upgradeTo(address(optimismPortalImpl));
        l1StandardBridgeProxy.setCode(address(l1StandardBridgeImpl).code);

        optimismPortal = OptimismPortal(payable(optimismPortalProxy));
        l1StandardBridge = L1StandardBridge(payable(l1StandardBridgeProxy));
        balanceClaimer = BalanceClaimer(address(balanceClaimerProxy));

        for (uint256 i = 0; i < 4; i++) {
            FuzzERC20 token = new FuzzERC20();
            token.initialize("name", "symbol", i == 0 ? 6 : 18);
            token.mint(address(l1StandardBridge), INITIAL_BALANCE);
            supportedTokens.push(token);
        }
        vm.deal(address(optimismPortal), INITIAL_BALANCE);
    }

    /// @custom:prop-id  0
    /// @custom:prop sanity checks for setup
    function property_setup() external {
        assert(address(optimismPortal.BALANCE_CLAIMER()) == address(balanceClaimer));
        assert(address(balanceClaimer.ethBalanceWithdrawer()) == address(optimismPortal));
        assert(address(balanceClaimer.erc20BalanceWithdrawer()) == address(l1StandardBridge));
        assert(address(l1StandardBridge.BALANCE_CLAIMER()) == address(balanceClaimer));
        assert(balanceClaimer.root() == bytes32(0));
    }
}
