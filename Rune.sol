// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ERC1155SupplyUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/token/onft/ERC1155/ONFT1155Upgradable.sol";

contract Rune is
    ERC1155SupplyUpgradeable,
    ONFT1155Upgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    uint256[5] public counters;
    uint256[5] public INITIAL_SUPPLIES;
    uint256[5] public MAX_SUPPLIES;

    // Seeds and minting limits
    uint32 private constant _globalSeed = 69;
    bool public _limitWalletsMinting;
    uint32 public lastVestedTime;
    uint32 public initialMintTime;
    mapping(address => uint32) public lastMintTime;
    mapping(uint => string) public tokenURI;

    event LimitMintingToggled(bool enabled);
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ONFT1155Upgradeable_init(
            "",
            0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675
        ); //mainent endpoint
        __Ownable_init();
        __Pausable_init();
        __ERC1155Supply_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        //set initial supplies
        INITIAL_SUPPLIES = [2, 1, 1, 1, 1];
        MAX_SUPPLIES = [700, 500, 80, 100, 300];
        //set uri for each material
        tokenURI[0] = ""; //wood
        tokenURI[1] = ""; //copper
        tokenURI[2] = ""; //gold
        tokenURI[3] = ""; //silver
        tokenURI[4] = ""; //mystery
    }

    //this is the public function that will be called to mint
    function mint() external whenNotPaused nonReentrant {
        getMaterials();
    }

    //this is the function will be used to vest tokens to the tresury
    function mintBatch(address to) public onlyOwner {
        require(to != address(0), "ERC1155: mint to the zero address");

        for (uint i = 0; i < 5; i++) {
            require(
                totalSupply(i) >= INITIAL_SUPPLIES[i],
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
            remainingSeconds = (initialMintTime +
                31536000 -
                uint32(block.timestamp));
        }

        uint256[] memory ids = new uint256[](5);
        uint256[] memory amounts = new uint256[](5);

        for (uint i = 0; i < 5; i++) {
            ids[i] = i;
            amounts[i] =
                (MAX_SUPPLIES[i] - totalSupply(i)) /
                (remainingSeconds / 2592000);
        }

        lastVestedTime = uint32(block.timestamp);

        _mintBatch(to, ids, amounts, "");
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
        _mintBatch(_msgSender(), ids, amounts, "");
    }

    function toggleLimitMinting() public onlyOwner {
        _limitWalletsMinting = !_limitWalletsMinting;
        emit LimitMintingToggled(_limitWalletsMinting);
    }

    function setURI(uint _id, string memory _uri) external onlyOwner {
        tokenURI[_id] = _uri;
        emit BatchMetadataUpdate(0, 4);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        internal
        override(ERC1155Upgradeable, ERC1155SupplyUpgradeable)
        whenNotPaused
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function uri(uint _id) public view override returns (string memory) {
        return tokenURI[_id];
    }

    // solidity overrides
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC1155Upgradeable, ONFT1155Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
