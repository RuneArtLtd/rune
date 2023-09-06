// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {MerkleProofUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
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
  uint256[5] public INITIAL_SUPPLIES;
  uint256[5] public MAX_SUPPLIES;

  // Seeds and minting limits
  uint32 private constant _globalSeed = 69;
  bool public _limitWalletsMinting;
  bool public presale;
  uint32 public lastVestedTime;
  uint32 public initialMintTime;
  bytes32 presaleRoot;
  mapping(address => uint32) public lastMintTime;

  IRuneToken public runeToken;

  event LimitMintingToggled(bool enabled);
  event PresaleRootSet(bytes32 root);

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
    INITIAL_SUPPLIES = [54, 54, 54, 54, 54];

    MAX_SUPPLIES = [700, 500, 80, 100, 300];
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
    require(remainingSeconds > 0, "Vesting is over Minting not allowed.");
    for (uint i = 0; i < 5; i++) {
      require(
        runeToken.totalSupply(i) >= INITIAL_SUPPLIES[i],
        "Initial supply not met for token type"
      );
    }

    require(
      lastVestedTime + 30 days <= block.timestamp,
      "Minting can only be performed once a month"
    ); //update this to per quarter if required

    uint32 remainingSeconds;

    if (initialMintTime == 0) {
      initialMintTime = uint32(block.timestamp);
      remainingSeconds = 31536000; //1 year
    } else {
      remainingSeconds = (initialMintTime + 31536000 - uint32(block.timestamp));
    }

    uint256[] memory ids = new uint256[](5);
    uint256[] memory amounts = new uint256[](5);

    for (uint i = 0; i < 5; i++) {
      ids[i] = i;
      amounts[i] =
        (MAX_SUPPLIES[i] - runeToken.totalSupply(i)) /
        (remainingSeconds / 2592000);
    }

    lastVestedTime = uint32(block.timestamp);

    runeToken.batchMint(to, ids, amounts, "");
  }

  //randomization for mint
  function rollMaterialType(
    uint256 previousRoll
  ) internal returns (uint256 id) {
    bytes memory currentSeed = abi.encodePacked(
      _globalSeed,
      uint32(block.timestamp),
      uint32(block.prevrandao),
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
          if (counters[idx] < INITIAL_SUPPLIES[idx]) {
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
    if (_limitWalletsMinting) {
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
    _limitWalletsMinting = !_limitWalletsMinting;
    emit LimitMintingToggled(_limitWalletsMinting);
  }

  function setPresaleRoot(bytes32 _presaleRoot) public onlyOwner {
    require(_presaleRoot != presaleRoot, "Already set");
    require(_presaleRoot != bytes32(0), "Cannot be null");
    presaleRoot = _presaleRoot;
    emit PresaleRootSet(_presaleRoot);
  }

  function setRune(address _runeToken) external onlyOwner {
    runeToken = IRuneToken(_runeToken);
  }

  function walletOf(address _owner) external returns (uint256[] memory) {
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
