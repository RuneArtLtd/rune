// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {MerkleProofUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {IRuneToken} from "./interfaces/IRuneToken.sol";

contract RuneMinter is
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable
{
    uint256[5] public counters;
    uint256[5] public initialSupplies;
    uint256[5] public maxSupplies;

    uint32 public lastVestedTime;
    uint32 public initialMintTime;
    uint32 public periodDurationInSeconds;
    uint8 public currentPeriodIndex;
    uint8 public totalPeriods;
    bool public limitWalletsMinting;
    bool public presale;
    uint16 _unused; // Placeholder to fill the slot

    bytes32 presaleRoot;
    mapping(address => uint32) public lastMintTime;
    uint32 private constant GLOBAL_SEED = 69;
    uint32 private constant SECONDS_IN_A_YEAR = 31536000;
    uint32 private constant SECONDS_IN_A_MONTH = 2592000;
    uint32 private constant MINTING_PERIOD = 30 days;

    event LimitMintingToggled(bool enabled);
    event PresaleRootSet(bytes32 root);
    event RuneSet(address rune);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _runeToken,
        bytes32 _presaleRoot
    ) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        runeToken = IRuneToken(_runeToken);
        //presale
        presale = true;

        presaleRoot = _presaleRoot;

        //set initial supplies must be divisable by 3
        initialSupplies = [54, 54, 54, 54, 54];

        maxSupplies = [700, 500, 80, 100, 300];
        limitWalletsMinting = true;

        totalPeriods = _totalPeriods;
        periodDurationInSeconds = _periodDurationInSeconds;
        currentPeriodIndex = 0;
    }

    //If not in presale
    function mint(bytes32[] memory proof) external whenNotPaused nonReentrant {
        if (presale) {
            bytes32 leaf = keccak256(
                bytes.concat(keccak256(abi.encode(_msgSender(), 1)))
            );
            require(
                MerkleProofUpgradeable.verify(proof, presaleRoot, leaf),
                "Invalid proof"
            );
            getMaterials();
        } else {
            getMaterials();
        }
    }

    //this is the function will be used to vest tokens to the tresury
    function mintBatch(address to) public onlyOwner {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(
            currentPeriodIndex < totalPeriods,
            "All vesting periods have passed"
        );

        for (uint i = 0; i < 5; i++) {
            require(
                runeToken.totalSupply(i) >= initialSupplies[i],
                "Initial supply not met for token type"
            );
        }

        require(
            lastVestedTime + periodDurationInSeconds <= block.timestamp,
            "Minting can only be performed once per period"
        );

        uint256[] memory ids = new uint256[](5);
        uint256[] memory amounts = new uint256[](5);

        uint8 remainingPeriods = totalPeriods - currentPeriodIndex;

        for (uint i = 0; i < 5; i++) {
            ids[i] = i;
            amounts[i] =
                (maxSupplies[i] - runeToken.totalSupply(i)) /
                remainingPeriods;
        }

        lastVestedTime = uint32(block.timestamp);
        currentPeriodIndex++;

        runeToken.batchMint(to, ids, amounts, "");
    }

    //randomization for mint
    function rollMaterialType(uint256 previousRoll) internal returns (uint256) {
        bytes memory currentSeed = abi.encodePacked(
            GLOBAL_SEED,
            uint32(block.timestamp),
            block.prevrandao,
            previousRoll,
            blockhash(block.number - 1),
            msg.sender,
            block.number
        );

        uint256 roll = uint256(keccak256(currentSeed)) % 200;

        uint256[] memory rollThresholds = new uint256[](5);
        rollThresholds[0] = 100;
        rollThresholds[1] = 150;
        rollThresholds[2] = 180;
        rollThresholds[3] = 195;
        rollThresholds[4] = 200;

        for (uint i = 0; i < 5; i++) {
            if (roll < rollThresholds[i]) {
                for (uint j = 0; j < 5; j++) {
                    uint idx = (i + j) % 5;
                    if (counters[idx] < initialSupplies[idx]) {
                        counters[idx]++;
                        return idx;
                    }
                }
                revert("All materials have been minted");
            }
        }
    }

    function getMaterials() internal {
        // check to see if address is allowed
        if (limitWalletsMinting) {
            require(
                uint32(block.timestamp) > lastMintTime[_msgSender()],
                "You must wait more time until your next mint."
            );
            // set lastMintTime
        }
        lastMintTime[_msgSender()] = uint32(block.timestamp) + 1 days;
        //
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);
        //
        amounts[0] = 1;
        amounts[1] = 1;
        amounts[2] = 1;
        //
        ids[0] = rollMaterialType(1);
        ids[1] = rollMaterialType(2);
        ids[2] = rollMaterialType(3);
        runeToken.batchMint(_msgSender(), ids, amounts, "");
    }

    function toggleLimitMinting() public onlyOwner {
        limitWalletsMinting = !limitWalletsMinting;
        emit LimitMintingToggled(limitWalletsMinting);
    }

    function setPresaleRoot(bytes32 _presaleRoot) public onlyOwner {
        require(_presaleRoot != presaleRoot, "Already set");
        require(_presaleRoot != bytes32(0), "Cannot be null");
        presaleRoot = _presaleRoot;
        emit PresaleRootSet(_presaleRoot);
    }

    function setRune(address _runeToken) external onlyOwner {
        runeToken = IRuneToken(_runeToken);
        emit RuneSet(_runeToken);
    }

    function walletOf(address _owner) external view returns (uint256[] memory) {
        uint256[] memory tokensOwned = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            tokensOwned[i] = runeToken.balanceOf(_owner, i);
        }
        return tokensOwned;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
