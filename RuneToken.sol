// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ERC1155SupplyUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {MerkleProofUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";
import "@layerzerolabs/solidity-examples/contracts/contracts-upgradable/token/onft/ERC1155/ONFT1155Upgradable.sol";

contract Rune is
    ERC1155SupplyUpgradeable,
    ONFT1155Upgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);
    event MinterSet(address _minter);
    mapping(uint => string) public tokenURI;
    address public minter;

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

        //set uri for each material
        tokenURI[0] = ""; //wood
        tokenURI[1] = ""; //copper
        tokenURI[2] = ""; //gold
        tokenURI[3] = ""; //silver
        tokenURI[4] = ""; //mystery
    }

    function setURI(uint _id, string memory _uri) external onlyOwner {
        tokenURI[_id] = _uri;
        emit BatchMetadataUpdate(0, 4);
    }
    
    function setMinter (address _minter) external onlyOwner {
        require(minter != _minter, "Already set");
        require(_minter != address(0), "Cannot be zero address");
        minter = _minter;
        emit MinterSet(_minter);
    }

    function batchMint(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external {
        require (_msgSender() == minter, "Only minter can mint");
        _mintBatch(to, ids, amounts, data);
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
