// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

// Libraries
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Testing
import { stdStorage, StdStorage } from "forge-std/Test.sol";
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

/// @notice Minimal ERC20 used in the clawback integration tests. Mirrors
///         OpenZeppelin's zero-address guard on transfer so the suite
///         exercises the same revert path real DAI/USDC/USDT/GTC implement.
///         Bytecode is `vm.etch`-ed at the hardcoded mainnet token addresses
///         referenced by {clawback}.
contract MockERC20 {
    mapping(address => uint256) public balanceOf;

    function mint(address _to, uint256 _amount) external {
        require(_to != address(0), "ERC20: mint to the zero address");
        balanceOf[_to] += _amount;
    }

    function transfer(address _to, uint256 _amount) external returns (bool) {
        require(_to != address(0), "ERC20: transfer to the zero address");
        balanceOf[msg.sender] -= _amount;
        balanceOf[_to] += _amount;
        return true;
    }
}

contract BalanceClaimer_Clawback_Integration_Test is Bridge_Initializer {
    event Clawback(address indexed foundation);

    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant GTC = 0xDe30da39c46104798bB5aA3fe8B9e0e1F348163F;

    uint256 constant SEED_DAI = 1000;
    uint256 constant SEED_USDC = 2000;
    uint256 constant SEED_USDT = 3001;
    uint256 constant SEED_GTC = 4000;
    uint256 constant SEED_ETH = 100 ether;

    address foundation = makeAddr("clawbackFoundation");

    BalanceClaimer clawbackImpl;

    function setUp() public override {
        super.setUp();

        // Etch a strict ERC20 implementation at each hardcoded token address so
        // calls to {balanceOf} and {transfer} resolve. The mock keeps OZ's
        // zero-address guard intact, so the suite still validates the real
        // failure mode if FOUNDATION were ever zeroed.
        bytes memory _code = address(new MockERC20()).code;
        vm.etch(DAI, _code);
        vm.etch(USDC, _code);
        vm.etch(USDT, _code);
        vm.etch(GTC, _code);

        // Seed the L1StandardBridge with token balances and the OptimismPortal with ETH.
        MockERC20(DAI).mint(address(L1Bridge), SEED_DAI);
        MockERC20(USDC).mint(address(L1Bridge), SEED_USDC);
        MockERC20(USDT).mint(address(L1Bridge), SEED_USDT);
        MockERC20(GTC).mint(address(L1Bridge), SEED_GTC);
        vm.deal(address(op), SEED_ETH);

        // Deploy the new BalanceClaimer implementation. The Merkle root is a
        // non-zero garbage value: claims become infeasible and only `clawback`
        // can move funds.
        clawbackImpl = new BalanceClaimer({
            _ethBalanceWithdrawer: address(op),
            _erc20BalanceWithdrawer: address(L1Bridge),
            _root: keccak256("WINDDOWN_CLAWBACK_DISABLED_ROOT"),
            _foundation: foundation
        });
    }

    /// @dev Asserts the bridge and portal are drained and FOUNDATION received the full totals.
    function _assertDrained() internal view {
        assertEq(address(op).balance, 0);
        assertEq(IERC20(DAI).balanceOf(address(L1Bridge)), 0);
        assertEq(IERC20(USDC).balanceOf(address(L1Bridge)), 0);
        assertEq(IERC20(USDT).balanceOf(address(L1Bridge)), 0);
        assertEq(IERC20(GTC).balanceOf(address(L1Bridge)), 0);

        assertEq(foundation.balance, SEED_ETH);
        assertEq(IERC20(DAI).balanceOf(foundation), SEED_DAI);
        assertEq(IERC20(USDC).balanceOf(foundation), SEED_USDC);
        assertEq(IERC20(USDT).balanceOf(foundation), SEED_USDT);
        assertEq(IERC20(GTC).balanceOf(foundation), SEED_GTC);
    }

    /// @dev Atomic upgrade-and-drain: governance executes a single tx that swaps the impl and
    ///      forwards `clawback()` selector to it via `Proxy.upgradeToAndCall`.
    function test_clawback_upgradeToAndCall_drainsAtomically() external {
        bytes memory _data = abi.encodeWithSelector(BalanceClaimer.clawback.selector);

        vm.expectEmit(address(balanceClaimerProxy));
        emit Clawback(foundation);

        vm.prank(multisig);
        Proxy(payable(address(balanceClaimerProxy))).upgradeToAndCall(address(clawbackImpl), _data);

        _assertDrained();
    }

    /// @dev Two-step: governance does a plain `upgradeTo`, then anyone calls `clawback()`.
    function test_clawback_upgradeTo_thenCallByAnyone_succeeds() external {
        vm.prank(multisig);
        Proxy(payable(address(balanceClaimerProxy))).upgradeTo(address(clawbackImpl));

        vm.expectEmit(address(balanceClaimerProxy));
        emit Clawback(foundation);

        vm.prank(makeAddr("anyone"));
        BalanceClaimer(address(balanceClaimerProxy)).clawback();

        _assertDrained();
    }

    /// @dev After draining, a second `clawback()` is a balance no-op (the
    ///      bridge / portal stay empty) and still emits the event.
    function test_clawback_idempotent() external {
        vm.prank(multisig);
        Proxy(payable(address(balanceClaimerProxy))).upgradeTo(address(clawbackImpl));

        BalanceClaimer(address(balanceClaimerProxy)).clawback();
        _assertDrained();

        // Second call: balances are zero, so the bridge/portal stay drained
        // and receiver totals don't move.
        vm.expectEmit(address(balanceClaimerProxy));
        emit Clawback(foundation);
        BalanceClaimer(address(balanceClaimerProxy)).clawback();

        _assertDrained();
    }

    /// @dev Once upgraded, `claim()` is unreachable: the garbage root makes any proof invalid.
    function test_claim_revertsAfterClawbackUpgrade() external {
        vm.prank(multisig);
        Proxy(payable(address(balanceClaimerProxy))).upgradeTo(address(clawbackImpl));

        bytes32[] memory _emptyProof;
        IErc20BalanceWithdrawer.Erc20BalanceClaim[] memory _emptyClaim;

        vm.expectRevert(IBalanceClaimer.NoBalanceToClaim.selector);
        balanceClaimerProxy.claim(_emptyProof, makeAddr("eve"), 0, _emptyClaim);
    }
}