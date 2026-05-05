// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { console } from "forge-std/console.sol";
import { Script } from "forge-std/Script.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ProxyAdmin } from "contracts/universal/ProxyAdmin.sol";
import { BalanceClaimer } from "contracts/L1/winddown/BalanceClaimer.sol";
import { WinddownConstants } from "../WinddownConstants.sol";

interface ISafe {
    function getOwners() external view returns (address[] memory);
    function nonce() external view returns (uint256);
    function getTransactionHash(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 _nonce
    ) external view returns (bytes32);
    function approveHash(bytes32 hashToApprove) external;
    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes calldata signatures
    ) external payable returns (bool);
}

/// @notice End-to-end clawback rehearsal against an unlocked-account fork
///         (e.g. anvil --fork-url $ETHEREUM_MAINNET_RPC). Deploys the v2
///         BalanceClaimer implementation and exercises the real prod call
///         path: a quorum of Safe owners pre-approves the safeTxHash via
///         `approveHash`, then `execTransaction` runs with stacked v=1
///         pre-validated signatures. The Safe calls `ProxyAdmin.upgradeAndCall`,
///         which in turn calls `Proxy.upgradeToAndCall` and runs `clawback()`.
///         Asserts the bridge / portal are drained and FOUNDATION received the
///         funds afterwards.
///
///         The deployer broadcast is delegated to forge's wallet flags: pass
///         `--account` and `--sender` so the deployer key stays in a keystore.
///         Safe owners are impersonated via `vm.prank`, no signer keys needed.
contract ClawbackUpgradeLocal is Script {
    /// @dev EIP-1967 admin slot: `bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)`.
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /// @dev Hard-coded: a 4-of-12 Safe needs four pre-approvals to execute.
    uint256 internal constant SAFE_THRESHOLD = 4;

    /// @dev Mirror the four token addresses baked into `BalanceClaimer` so we
    ///      can read pre-clawback balances before the new impl is deployed.
    ///      Keep in sync with `contracts/L1/winddown/BalanceClaimer.sol`.
    address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal constant GTC = 0xDe30da39c46104798bB5aA3fe8B9e0e1F348163F;

    /// @dev ETH balance of one account + ERC-20 balances of another account, in
    ///      the canonical [DAI, USDC, USDT, GTC] order.
    struct Snapshot {
        uint256 eth;
        uint256[4] tokens;
    }

    function run() public {
        require(WinddownConstants.BALANCE_CLAIMER_PROXY != address(0), "BALANCE_CLAIMER_PROXY unset in WinddownConstants");

        address foundation = WinddownConstants.FOUNDATION;

        // Capture pre-clawback balances so we can verify the funds actually
        // land at FOUNDATION, not just that the source contracts emptied.
        Snapshot memory _sourcesBefore = _snapshot(WinddownConstants.OPTIMISM_PORTAL_PROXY, WinddownConstants.L1_STANDARD_BRIDGE_PROXY);
        Snapshot memory _foundationBefore = _snapshot(foundation, foundation);

        // 1. Deploy the v2 implementation. Signing is delegated to forge's
        //    wallet flags (`--account` / `--sender`) so the deployer key
        //    stays in a keystore.
        //
        //    The deployer is intentionally NOT pre-funded here to catch a case of unfunded deployer.
        vm.startBroadcast();
        BalanceClaimer newImpl = new BalanceClaimer({
            _ethBalanceWithdrawer: WinddownConstants.OPTIMISM_PORTAL_PROXY,
            _erc20BalanceWithdrawer: WinddownConstants.L1_STANDARD_BRIDGE_PROXY,
            _root: WinddownConstants.CLAWBACK_GARBAGE_ROOT
        });
        vm.stopBroadcast();

        console.log("New BalanceClaimer (clawback) impl deployed at:", address(newImpl));
        assert(newImpl.FOUNDATION() == foundation);

        // 2. Resolve the prod call path: the proxy's EIP-1967 admin slot
        //    points at the OP ProxyAdmin contract; the ProxyAdmin's owner is
        //    the Safe authorized to upgrade. We impersonate the Safe so the
        //    rehearsal exercises Safe → ProxyAdmin → Proxy → impl, the same
        //    chain prod will hit.
        ProxyAdmin proxyAdmin = ProxyAdmin(
            address(uint160(uint256(vm.load(WinddownConstants.BALANCE_CLAIMER_PROXY, ADMIN_SLOT))))
        );
        ISafe safe = ISafe(proxyAdmin.owner());
        console.log("BalanceClaimer ProxyAdmin:", address(proxyAdmin));
        console.log("ProxyAdmin owner (Safe):  ", address(safe));

        // 3. Build the same ProxyAdmin.upgradeAndCall calldata the Safe Tx
        //    Builder will execute in prod.
        bytes memory _outerCall = abi.encodeCall(
            ProxyAdmin.upgradeAndCall,
            (
                payable(WinddownConstants.BALANCE_CLAIMER_PROXY),
                address(newImpl),
                abi.encodeCall(BalanceClaimer.clawback, ())
            )
        );

        // 4. Pick the lowest `SAFE_THRESHOLD` owners (Safe requires sigs
        //    sorted ascending by signer address) and impersonate each one to
        //    pre-approve the safeTxHash via `approveHash`. With v=1 sigs and
        //    on-chain approvals, no real signer key is needed.
        address[] memory _signers = _lowestOwners(safe.getOwners(), SAFE_THRESHOLD);
        bytes32 _safeTxHash = safe.getTransactionHash(
            address(proxyAdmin), 0, _outerCall, 0, 0, 0, 0, address(0), address(0), safe.nonce()
        );

        for (uint256 _i; _i < SAFE_THRESHOLD; ++_i) {
            vm.deal(_signers[_i], 1 ether);
            vm.prank(_signers[_i]);
            safe.approveHash(_safeTxHash);
        }

        // 5. Build stacked pre-validated signatures (r=signer, s=0, v=1) and
        //    submit `execTransaction` as the first signer. The Safe verifies
        //    each signature against the on-chain approval and executes the
        //    upgrade through ProxyAdmin → Proxy → BalanceClaimer.clawback().
        bytes memory _signatures;
        for (uint256 _i; _i < SAFE_THRESHOLD; ++_i) {
            _signatures = bytes.concat(
                _signatures,
                bytes32(uint256(uint160(_signers[_i]))),
                bytes32(0),
                bytes1(0x01)
            );
        }
        vm.prank(_signers[0]);
        require(
            safe.execTransaction(
                address(proxyAdmin),
                0,
                _outerCall,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                _signatures
            ),
            "Safe: execTransaction returned false"
        );

        _assertDrained(_sourcesBefore, _foundationBefore);
    }

    /// @dev Returns the `_n` smallest addresses from `_owners` (selection-style)
    ///      so the corresponding pre-validated signatures end up sorted
    ///      ascending — Safe rejects unordered signatures.
    function _lowestOwners(address[] memory _owners, uint256 _n) internal pure returns (address[] memory _out) {
        require(_owners.length >= _n, "Safe: not enough owners");
        // Sort the input copy ascending (selection sort, n <= 12 so cost is trivial).
        for (uint256 _i; _i < _owners.length; ++_i) {
            for (uint256 _j = _i + 1; _j < _owners.length; ++_j) {
                if (_owners[_j] < _owners[_i]) (_owners[_i], _owners[_j]) = (_owners[_j], _owners[_i]);
            }
        }
        _out = new address[](_n);
        for (uint256 _i; _i < _n; ++_i) _out[_i] = _owners[_i];
    }

    /// @dev Returns `_ethHolder`'s ETH balance and `_tokenHolder`'s balances
    ///      across the four clawback-tracked tokens.
    function _snapshot(address _ethHolder, address _tokenHolder) internal view returns (Snapshot memory _s) {
        _s.eth = _ethHolder.balance;
        address[4] memory _tokens = [DAI, USDC, USDT, GTC];
        for (uint256 _i; _i < _tokens.length; ++_i) {
            _s.tokens[_i] = IERC20(_tokens[_i]).balanceOf(_tokenHolder);
        }
    }

    function _assertDrained(Snapshot memory _sourcesBefore, Snapshot memory _foundationBefore) internal view {
        Snapshot memory _sourcesAfter = _snapshot(WinddownConstants.OPTIMISM_PORTAL_PROXY, WinddownConstants.L1_STANDARD_BRIDGE_PROXY);
        Snapshot memory _foundationAfter = _snapshot(WinddownConstants.FOUNDATION, WinddownConstants.FOUNDATION);

        assert(_sourcesAfter.eth == 0);
        assert(_foundationAfter.eth == _foundationBefore.eth + _sourcesBefore.eth);
        string[4] memory _names = ["DAI", "USDC", "USDT", "GTC"];
        for (uint256 _i; _i < _names.length; ++_i) {
            assert(_sourcesAfter.tokens[_i] == 0);
            assert(_foundationAfter.tokens[_i] == _foundationBefore.tokens[_i] + _sourcesBefore.tokens[_i]);
            console.log(string.concat("Foundation ", _names[_i], " delta:"), _foundationAfter.tokens[_i] - _foundationBefore.tokens[_i]);
        }
        console.log("Foundation ETH delta:", _foundationAfter.eth - _foundationBefore.eth);
    }
}
