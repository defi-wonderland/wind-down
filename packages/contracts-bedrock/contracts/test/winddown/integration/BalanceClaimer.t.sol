// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

// Libraries
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Testing
import { Test, stdStorage, StdStorage } from "forge-std/Test.sol";
import { Bridge_Initializer } from "../../CommonTest.t.sol";
import { MerkleTreeGenerator } from "../../libraries/MerkleTreeGenerator.t.sol";

// Contracts
import { BalanceClaimer } from "../../../L1/winddown/BalanceClaimer.sol";
import { Proxy } from "../../../universal/Proxy.sol";

// Interfaces
import { IBalanceClaimer } from "../../../L1/interfaces/winddown/IBalanceClaimer.sol";
import { IErc20BalanceWithdrawer } from "../../../L1/interfaces/winddown/IErc20BalanceWithdrawer.sol";
import { IEthBalanceWithdrawer } from "../../../L1/interfaces/winddown/IEthBalanceWithdrawer.sol";

contract BalanceClaimerIntegration_Test is Bridge_Initializer {
    using stdStorage for StdStorage;

    MerkleTreeGenerator merkleTreeGenerator = new MerkleTreeGenerator();

    address aliceClaimer = makeAddr("aliceClaimer");
    address bobClaimer = makeAddr("bobClaimer");
    address charlieClaimer = makeAddr("charlieClaimer");

    address token1 = address(new ERC20("token1", "TK1"));
    address token2 = address(new ERC20("token2", "TK2"));
    address token3 = address(new ERC20("token3", "TK3"));

    ClaimParams aliceClaimParams;
    ClaimParams bobClaimParams;
    ClaimParams charlieClaimParams;

    bytes32[] leaves;
    bytes32[] tree;

    struct ClaimParams {
        address user;
        uint256 ethBalance;
        IErc20BalanceWithdrawer.Erc20BalanceClaim[] erc20TokenBalances;
    }

    function setUp() public override {
        super.setUp();

        // The Balance Claimer is deployed with the Merkle root and when L1StandardBridge and OptimismPortal are deployed
        balanceClaimerImpl = new BalanceClaimer({
            _ethBalanceWithdrawer: address(op),
            _erc20BalanceWithdrawer: address(L1Bridge),
            _root: keccak256("mockRoot")
        });

        vm.prank(multisig);
        Proxy(payable(address(balanceClaimerProxy))).upgradeTo(address(balanceClaimerImpl));

        merkleTreeGenerator = new MerkleTreeGenerator();

        aliceClaimParams.user = aliceClaimer;
        aliceClaimParams.ethBalance = 100;

        bobClaimParams.user = bobClaimer;
        bobClaimParams.ethBalance = 200;

        charlieClaimParams.user = charlieClaimer;
        charlieClaimParams.ethBalance = 300;

        aliceClaimParams.erc20TokenBalances.push(IErc20BalanceWithdrawer.Erc20BalanceClaim({ token: token2, balance: 100 }));

        bobClaimParams.erc20TokenBalances.push(IErc20BalanceWithdrawer.Erc20BalanceClaim({ token: token1, balance: 200 }));

        bobClaimParams.erc20TokenBalances.push(IErc20BalanceWithdrawer.Erc20BalanceClaim({ token: token3, balance: 300 }));

        charlieClaimParams.erc20TokenBalances.push(
            IErc20BalanceWithdrawer.Erc20BalanceClaim({ token: token1, balance: 400 })
        );

        charlieClaimParams.erc20TokenBalances.push(
            IErc20BalanceWithdrawer.Erc20BalanceClaim({ token: token2, balance: 500 })
        );

        charlieClaimParams.erc20TokenBalances.push(
            IErc20BalanceWithdrawer.Erc20BalanceClaim({ token: token3, balance: 600 })
        );

        ClaimParams[] memory _claimParams = new ClaimParams[](3);

        _claimParams[0] = aliceClaimParams;
        _claimParams[1] = bobClaimParams;
        _claimParams[2] = charlieClaimParams;

        leaves = _getLeaves(_claimParams);
        tree = _mockRoot(leaves);

        deal(token1, address(balanceClaimerProxy.ERC20_BALANCE_WITHDRAWER()), 600);
        deal(token2, address(balanceClaimerProxy.ERC20_BALANCE_WITHDRAWER()), 600);
        deal(token3, address(balanceClaimerProxy.ERC20_BALANCE_WITHDRAWER()), 900);
        vm.deal(address(balanceClaimerProxy.ETH_BALANCE_WITHDRAWER()), 600);
    }

    /// @dev Get the leaves for the merkle tree
    function _getLeaves(ClaimParams[] memory _claimParams) internal pure returns (bytes32[] memory _leaves) {
        _leaves = new bytes32[](_claimParams.length);
        for (uint256 _i; _i < _claimParams.length; _i++) {
            _leaves[_i] = keccak256(
                bytes.concat(
                    keccak256(
                        abi.encode(
                            _claimParams[_i].user, _claimParams[_i].ethBalance, _claimParams[_i].erc20TokenBalances
                        )
                    )
                )
            );
        }
    }

    /// @dev Generates the merkle tree, mock the root and set it in the storage
    function _mockRoot(bytes32[] memory _leaves) internal returns (bytes32[] memory _tree) {
        _tree = merkleTreeGenerator.generateMerkleTree(_leaves);
        bytes32 _root = _tree[0];

        balanceClaimerImpl = new BalanceClaimer({
            _ethBalanceWithdrawer: address(op),
            _erc20BalanceWithdrawer: address(L1Bridge),
            _root: _root
        });
        vm.prank(multisig);
        Proxy(payable(address(balanceClaimerProxy))).upgradeTo(address(balanceClaimerImpl));
    }

    /// @dev Test that the claim function succeeds
    function test_claim_succeeds() external {
        bytes32[] memory _aliceClaimerProofs =
            merkleTreeGenerator.getProof(tree, merkleTreeGenerator.getIndex(tree, leaves[0]));
        balanceClaimerProxy.claim(
            _aliceClaimerProofs, aliceClaimParams.user, aliceClaimParams.ethBalance, aliceClaimParams.erc20TokenBalances
        );

        bytes32[] memory _bobClaimerProofs =
            merkleTreeGenerator.getProof(tree, merkleTreeGenerator.getIndex(tree, leaves[1]));
        balanceClaimerProxy.claim(
            _bobClaimerProofs, bobClaimParams.user, bobClaimParams.ethBalance, bobClaimParams.erc20TokenBalances
        );

        bytes32[] memory _charlieClaimerProofs =
            merkleTreeGenerator.getProof(tree, merkleTreeGenerator.getIndex(tree, leaves[2]));
        balanceClaimerProxy.claim(
            _charlieClaimerProofs,
            charlieClaimParams.user,
            charlieClaimParams.ethBalance,
            charlieClaimParams.erc20TokenBalances
        );

        // Assertions
        assertEq(address(balanceClaimerProxy.ETH_BALANCE_WITHDRAWER()).balance, 0);
        assertEq(ERC20(token1).balanceOf(address(balanceClaimerProxy.ERC20_BALANCE_WITHDRAWER())), 0);
        assertEq(ERC20(token2).balanceOf(address(balanceClaimerProxy.ERC20_BALANCE_WITHDRAWER())), 0);
        assertEq(ERC20(token3).balanceOf(address(balanceClaimerProxy.ERC20_BALANCE_WITHDRAWER())), 0);

        assertEq(aliceClaimer.balance, aliceClaimParams.ethBalance);
        assertEq(ERC20(token2).balanceOf(aliceClaimer), aliceClaimParams.erc20TokenBalances[0].balance);

        assertEq(bobClaimer.balance, bobClaimParams.ethBalance);
        assertEq(ERC20(token1).balanceOf(bobClaimer), bobClaimParams.erc20TokenBalances[0].balance);
        assertEq(ERC20(token3).balanceOf(bobClaimer), bobClaimParams.erc20TokenBalances[1].balance);

        assertEq(charlieClaimer.balance, charlieClaimParams.ethBalance);
        assertEq(ERC20(token1).balanceOf(charlieClaimer), charlieClaimParams.erc20TokenBalances[0].balance);
        assertEq(ERC20(token2).balanceOf(charlieClaimer), charlieClaimParams.erc20TokenBalances[1].balance);
        assertEq(ERC20(token3).balanceOf(charlieClaimer), charlieClaimParams.erc20TokenBalances[2].balance);
    }

    /// @dev Test that the claim function reverts when the user is invalid
    function test_claim_reverts_InvalidUser() external {
        bytes32[] memory _aliceClaimerProofs =
            merkleTreeGenerator.getProof(tree, merkleTreeGenerator.getIndex(tree, leaves[0]));

        vm.expectRevert(IBalanceClaimer.NoBalanceToClaim.selector);

        // using charlie user instead of alice
        balanceClaimerProxy.claim(
            _aliceClaimerProofs,
            charlieClaimParams.user,
            aliceClaimParams.ethBalance,
            aliceClaimParams.erc20TokenBalances
        );
    }

    /// @dev Test that the claim function reverts when the proof is invalid
    function test_claim_reverts_InvalidProof() external {
        // using bob proofs instead of alice
        bytes32[] memory _aliceClaimerProofs =
            merkleTreeGenerator.getProof(tree, merkleTreeGenerator.getIndex(tree, leaves[1]));

        vm.expectRevert(IBalanceClaimer.NoBalanceToClaim.selector);
        balanceClaimerProxy.claim(
            _aliceClaimerProofs, aliceClaimParams.user, aliceClaimParams.ethBalance, aliceClaimParams.erc20TokenBalances
        );
    }

    /// @dev Test that the claim function reverts when the eth balance is invalid
    function test_claim_reverts_InvalidEthBalance() external {
        bytes32[] memory _aliceClaimerProofs =
            merkleTreeGenerator.getProof(tree, merkleTreeGenerator.getIndex(tree, leaves[0]));

        // using charlie eth balance instead of alice
        vm.expectRevert(IBalanceClaimer.NoBalanceToClaim.selector);
        balanceClaimerProxy.claim(
            _aliceClaimerProofs,
            aliceClaimParams.user,
            charlieClaimParams.ethBalance,
            aliceClaimParams.erc20TokenBalances
        );
    }

    /// @dev Test that the claim function reverts when the erc20 balance is invalid
    function test_claim_reverts_InvalidErc20Balance() external {
        // using bob proofs instead of alice
        bytes32[] memory _aliceClaimerProofs =
            merkleTreeGenerator.getProof(tree, merkleTreeGenerator.getIndex(tree, leaves[0]));

        vm.expectRevert(IBalanceClaimer.NoBalanceToClaim.selector);

        // using bob erc20 balance instead of alice
        balanceClaimerProxy.claim(
            _aliceClaimerProofs, aliceClaimParams.user, aliceClaimParams.ethBalance, bobClaimParams.erc20TokenBalances
        );
    }
}

contract BalanceClaimer_Clawback_Integration_Test is Test {
    event Clawback(
        address indexed foundation,
        uint256 ethTotal,
        IErc20BalanceWithdrawer.Erc20BalanceClaim[] erc20Totals
    );

    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant GTC = 0xDe30da39c46104798bB5aA3fe8B9e0e1F348163F;

    /// @dev Live mainnet contracts the test runs against on a forked chain.
    address constant PORTAL = 0xb26Fd985c5959bBB382BAFdD0b879E149e48116c;
    address constant BRIDGE = 0xD0204B9527C1bA7bD765Fa5CCD9355d38338272b;
    address constant CLAIMER_PROXY = 0x0Ca4C7A370E0155c77a33e78443a54D749E0BC21;

    /// @dev Mainnet block the fork is pinned to. Mainnet balances at this
    ///      height are the source of truth for what `clawback` should drain.
    uint256 constant FORK_BLOCK = 25002349;

    /// @dev EIP-1967 admin slot.
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    BalanceClaimer clawbackImpl;
    address foundation;
    address proxyAdmin;

    // Real bridge / portal balances at FORK_BLOCK; captured at setUp.
    uint256 ethTotal;
    uint256 daiTotal;
    uint256 usdcTotal;
    uint256 usdtTotal;
    uint256 gtcTotal;

    // Foundation pre-clawback balances; assertions use deltas instead of
    // overwriting Foundation state, so the test runs on the real chain.
    uint256 fndEth;
    uint256 fndDai;
    uint256 fndUsdc;
    uint256 fndUsdt;
    uint256 fndGtc;

    function setUp() public {
        // Pin to a known mainnet block so the captured balances are stable.
        vm.createSelectFork(vm.envString("ETHEREUM_MAINNET_RPC"), FORK_BLOCK);

        // Deploy the new BalanceClaimer implementation wired to the live
        // mainnet portal / bridge proxies. Garbage Merkle root neutralizes
        // {claim}; only {clawback} can move funds.
        clawbackImpl = new BalanceClaimer({
            _ethBalanceWithdrawer: PORTAL,
            _erc20BalanceWithdrawer: BRIDGE,
            _root: keccak256("WINDDOWN_CLAWBACK_DISABLED_ROOT")
        });

        foundation = clawbackImpl.FOUNDATION();
        proxyAdmin = address(uint160(uint256(vm.load(CLAIMER_PROXY, ADMIN_SLOT))));
        vm.deal(proxyAdmin, 1 ether); // gas for the upgrade tx

        ethTotal = PORTAL.balance;
        daiTotal = IERC20(DAI).balanceOf(BRIDGE);
        usdcTotal = IERC20(USDC).balanceOf(BRIDGE);
        usdtTotal = IERC20(USDT).balanceOf(BRIDGE);
        gtcTotal = IERC20(GTC).balanceOf(BRIDGE);

        fndEth = foundation.balance;
        fndDai = IERC20(DAI).balanceOf(foundation);
        fndUsdc = IERC20(USDC).balanceOf(foundation);
        fndUsdt = IERC20(USDT).balanceOf(foundation);
        fndGtc = IERC20(GTC).balanceOf(foundation);
    }

    /// @dev Build the same filtered claim array {clawback} composes from
    ///      the real bridge balances at FORK_BLOCK.
    function _expectedClaims() internal view returns (IErc20BalanceWithdrawer.Erc20BalanceClaim[] memory _out) {
        address[4] memory _tokens = [DAI, USDC, USDT, GTC];
        uint256[4] memory _bals = [daiTotal, usdcTotal, usdtTotal, gtcTotal];
        uint256 _nonZero;
        for (uint256 i; i < 4; ++i) if (_bals[i] != 0) ++_nonZero;
        _out = new IErc20BalanceWithdrawer.Erc20BalanceClaim[](_nonZero);
        uint256 _j;
        for (uint256 i; i < 4; ++i) {
            if (_bals[i] != 0) {
                _out[_j++] = IErc20BalanceWithdrawer.Erc20BalanceClaim({ token: _tokens[i], balance: _bals[i] });
            }
        }
    }

    /// @dev Asserts the bridge / portal are drained and FOUNDATION's deltas
    ///      match the captured pre-clawback totals.
    function _assertDrained() internal view {
        assertEq(PORTAL.balance, 0);
        assertEq(IERC20(DAI).balanceOf(BRIDGE), 0);
        assertEq(IERC20(USDC).balanceOf(BRIDGE), 0);
        assertEq(IERC20(USDT).balanceOf(BRIDGE), 0);
        assertEq(IERC20(GTC).balanceOf(BRIDGE), 0);

        assertEq(foundation.balance, fndEth + ethTotal);
        assertEq(IERC20(DAI).balanceOf(foundation), fndDai + daiTotal);
        assertEq(IERC20(USDC).balanceOf(foundation), fndUsdc + usdcTotal);
        assertEq(IERC20(USDT).balanceOf(foundation), fndUsdt + usdtTotal);
        assertEq(IERC20(GTC).balanceOf(foundation), fndGtc + gtcTotal);
    }

    /// @dev Atomic upgrade-and-drain: governance executes a single tx that swaps the impl and
    ///      forwards `clawback()` selector to it via `Proxy.upgradeToAndCall`.
    function test_clawback_upgradeToAndCall_drainsAtomically() external {
        bytes memory _data = abi.encodeWithSelector(BalanceClaimer.clawback.selector);

        vm.expectEmit(CLAIMER_PROXY);
        emit Clawback(foundation, ethTotal, _expectedClaims());

        vm.prank(proxyAdmin);
        Proxy(payable(CLAIMER_PROXY)).upgradeToAndCall(address(clawbackImpl), _data);

        _assertDrained();
    }

    /// @dev Two-step: governance does a plain `upgradeTo`, then anyone calls `clawback()`.
    function test_clawback_upgradeTo_thenCallByAnyone_succeeds() external {
        vm.prank(proxyAdmin);
        Proxy(payable(CLAIMER_PROXY)).upgradeTo(address(clawbackImpl));

        vm.expectEmit(CLAIMER_PROXY);
        emit Clawback(foundation, ethTotal, _expectedClaims());

        vm.prank(makeAddr("anyone"));
        BalanceClaimer(CLAIMER_PROXY).clawback();

        _assertDrained();
    }

    /// @dev After draining, a second `clawback()` is a balance no-op and emits
    ///      the event with zero ETH total and an empty erc20 totals array
    ///      (since clawback filters zero-balance tokens).
    function test_clawback_idempotent() external {
        vm.prank(proxyAdmin);
        Proxy(payable(CLAIMER_PROXY)).upgradeTo(address(clawbackImpl));

        BalanceClaimer(CLAIMER_PROXY).clawback();
        _assertDrained();

        IErc20BalanceWithdrawer.Erc20BalanceClaim[] memory _empty;
        vm.expectEmit(CLAIMER_PROXY);
        emit Clawback(foundation, 0, _empty);
        BalanceClaimer(CLAIMER_PROXY).clawback();

        _assertDrained();
    }

    /// @dev Once upgraded, `claim()` is unreachable: the garbage root makes any proof invalid.
    function test_claim_revertsAfterClawbackUpgrade() external {
        vm.prank(proxyAdmin);
        Proxy(payable(CLAIMER_PROXY)).upgradeTo(address(clawbackImpl));

        bytes32[] memory _emptyProof;
        IErc20BalanceWithdrawer.Erc20BalanceClaim[] memory _emptyClaim;

        vm.expectRevert(IBalanceClaimer.NoBalanceToClaim.selector);
        IBalanceClaimer(CLAIMER_PROXY).claim(_emptyProof, makeAddr("eve"), 0, _emptyClaim);
    }
}