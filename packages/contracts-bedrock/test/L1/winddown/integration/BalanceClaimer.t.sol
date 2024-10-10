// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

// Testing
import { stdStorage, StdStorage } from "forge-std/Test.sol";
import { Bridge_Initializer } from "test/setup/Bridge_Initializer.sol";
import { MerkleTreeGenerator } from "test/libraries/MerkleTreeGenerator.t.sol";

// Contracts
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { BalanceClaimer } from "src/L1/winddown/BalanceClaimer.sol";

// Interfaces
import { IBalanceClaimer } from "src/L1/interfaces/winddown/IBalanceClaimer.sol";
import { IBalanceWithdrawer } from "src/L1/interfaces/winddown/IBalanceWithdrawer.sol";

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
        IBalanceWithdrawer.Erc20BalanceClaim[] erc20TokenBalances;
    }

    function setUp() public override {
        super.setUp();
        merkleTreeGenerator = new MerkleTreeGenerator();

        aliceClaimParams.user = aliceClaimer;
        aliceClaimParams.ethBalance = 100;

        bobClaimParams.user = bobClaimer;
        bobClaimParams.ethBalance = 200;

        charlieClaimParams.user = charlieClaimer;
        charlieClaimParams.ethBalance = 300;

        aliceClaimParams.erc20TokenBalances.push(IBalanceWithdrawer.Erc20BalanceClaim({ token: token2, balance: 100 }));

        bobClaimParams.erc20TokenBalances.push(IBalanceWithdrawer.Erc20BalanceClaim({ token: token1, balance: 200 }));

        bobClaimParams.erc20TokenBalances.push(IBalanceWithdrawer.Erc20BalanceClaim({ token: token3, balance: 300 }));

        charlieClaimParams.erc20TokenBalances.push(
            IBalanceWithdrawer.Erc20BalanceClaim({ token: token1, balance: 400 })
        );

        charlieClaimParams.erc20TokenBalances.push(
            IBalanceWithdrawer.Erc20BalanceClaim({ token: token2, balance: 500 })
        );

        charlieClaimParams.erc20TokenBalances.push(
            IBalanceWithdrawer.Erc20BalanceClaim({ token: token3, balance: 600 })
        );

        ClaimParams[] memory _claimParams = new ClaimParams[](3);

        _claimParams[0] = aliceClaimParams;
        _claimParams[1] = bobClaimParams;
        _claimParams[2] = charlieClaimParams;

        leaves = _getLeaves(_claimParams);
        tree = _mockRoot(leaves);

        deal(token1, address(balanceClaimer.erc20BalanceWithdrawer()), 600);
        deal(token2, address(balanceClaimer.erc20BalanceWithdrawer()), 600);
        deal(token3, address(balanceClaimer.erc20BalanceWithdrawer()), 900);
        vm.deal(address(balanceClaimer.ethBalanceWithdrawer()), 600);
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
        stdstore.target(address(balanceClaimer)).sig(IBalanceClaimer.root.selector).checked_write(_root);
    }

    /// @dev Test that the claim function succeeds
    function test_claim_succeeds() external {
        bytes32[] memory _aliceClaimerProofs =
            merkleTreeGenerator.getProof(tree, merkleTreeGenerator.getIndex(tree, leaves[0]));
        balanceClaimer.claim(
            _aliceClaimerProofs, aliceClaimParams.user, aliceClaimParams.ethBalance, aliceClaimParams.erc20TokenBalances
        );

        bytes32[] memory _bobClaimerProofs =
            merkleTreeGenerator.getProof(tree, merkleTreeGenerator.getIndex(tree, leaves[1]));
        balanceClaimer.claim(
            _bobClaimerProofs, bobClaimParams.user, bobClaimParams.ethBalance, bobClaimParams.erc20TokenBalances
        );

        bytes32[] memory _charlieClaimerProofs =
            merkleTreeGenerator.getProof(tree, merkleTreeGenerator.getIndex(tree, leaves[2]));
        balanceClaimer.claim(
            _charlieClaimerProofs,
            charlieClaimParams.user,
            charlieClaimParams.ethBalance,
            charlieClaimParams.erc20TokenBalances
        );

        // Assertions
        assertEq(address(balanceClaimer.ethBalanceWithdrawer()).balance, 0);
        assertEq(ERC20(token1).balanceOf(address(balanceClaimer.erc20BalanceWithdrawer())), 0);
        assertEq(ERC20(token2).balanceOf(address(balanceClaimer.erc20BalanceWithdrawer())), 0);
        assertEq(ERC20(token3).balanceOf(address(balanceClaimer.erc20BalanceWithdrawer())), 0);

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
    function test_claim_invalid_user_reverts() external {
        bytes32[] memory _aliceClaimerProofs =
            merkleTreeGenerator.getProof(tree, merkleTreeGenerator.getIndex(tree, leaves[0]));

        vm.expectRevert(IBalanceClaimer.NoBalanceToClaim.selector);

        // using charlie user instead of alice
        balanceClaimer.claim(
            _aliceClaimerProofs,
            charlieClaimParams.user,
            aliceClaimParams.ethBalance,
            aliceClaimParams.erc20TokenBalances
        );
    }

    /// @dev Test that the claim function reverts when the proof is invalid
    function test_claim_invalid_proof_reverts() external {
        // using bob proofs instead of alice
        bytes32[] memory _aliceClaimerProofs =
            merkleTreeGenerator.getProof(tree, merkleTreeGenerator.getIndex(tree, leaves[1]));

        vm.expectRevert(IBalanceClaimer.NoBalanceToClaim.selector);
        balanceClaimer.claim(
            _aliceClaimerProofs, aliceClaimParams.user, aliceClaimParams.ethBalance, aliceClaimParams.erc20TokenBalances
        );
    }

    /// @dev Test that the claim function reverts when the eth balance is invalid
    function test_claim_invalid_eth_balance_reverts() external {
        bytes32[] memory _aliceClaimerProofs =
            merkleTreeGenerator.getProof(tree, merkleTreeGenerator.getIndex(tree, leaves[0]));

        // using charlie eth balance instead of alice
        vm.expectRevert(IBalanceClaimer.NoBalanceToClaim.selector);
        balanceClaimer.claim(
            _aliceClaimerProofs,
            aliceClaimParams.user,
            charlieClaimParams.ethBalance,
            aliceClaimParams.erc20TokenBalances
        );
    }

    /// @dev Test that the claim function reverts when the erc20 balance is invalid
    function test_claim_invalid_erc20_balance_reverts() external {
        // using bob proofs instead of alice
        bytes32[] memory _aliceClaimerProofs =
            merkleTreeGenerator.getProof(tree, merkleTreeGenerator.getIndex(tree, leaves[0]));

        vm.expectRevert(IBalanceClaimer.NoBalanceToClaim.selector);

        // using bob erc20 balance instead of alice
        balanceClaimer.claim(
            _aliceClaimerProofs, aliceClaimParams.user, aliceClaimParams.ethBalance, bobClaimParams.erc20TokenBalances
        );
    }
}
