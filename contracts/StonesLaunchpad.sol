// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/// @notice Contract cloning contract
import "@openzeppelin/contracts/proxy/Clones.sol";
/// @notice Ownable contract pattern
import "@openzeppelin/contracts/access/Ownable.sol";
/// @notice Reentrancy guard library
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
/// @notice NFTix ERC165 Interface
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "hardhat/console.sol";

/// @notice Stones ERC721 Interface
import "./interfaces/IStonesERC721.sol";

/// @notice Same Address Error
error SameAddress();
/// @notice Zero Address Error
error ZeroAddress();
/// @notice Transaction Fallback Disabled
error FallbackDisabled();

/**
 * @title StonesLaunchpad
 * @notice ERC721 Launchpad contract for minting NFTs
 * @dev This contract allows to mint NFTs for a fixed price
 * @author Stones Protocol | SajeBlockchain
 */
contract StonesLaunchpad is Ownable, ReentrancyGuard, ERC165 {
    /// @notice cheaply clone contract functions in an immuatable way
    using Clones for address;

    /// @notice Event emitted when a new ERC721 clone is created
    event NewClone(address indexed _newClone, address indexed _owner);

    /// @notice Event emitted when a new implementation of the ERC721 is created and the base ERC721 contract changes
    event ImplementationERC721Changed(address indexed ERC721Base);

    /// @notice Base ERC721 address
    address public baseContract;

    /// @notice Base ERC721 address
    address public defaultPlatformAdmin;

    /// @notice ERC721 contracts mappen by owner
    mapping(address => address[]) public ERC721Contracts;

    /// @notice disabling fallback recieve
    receive() external payable {
        revert FallbackDisabled();
    }
    fallback() external payable {
        revert FallbackDisabled();
    }

    constructor(address baseContract_) Ownable(msg.sender) {
        if (baseContract_ == address(0)) revert ZeroAddress();

        baseContract = baseContract_;
    }

    function createERC721(
        string memory name_,
        string memory symbol_,
        string memory uri_,
        uint256 presalePrice_,
        uint256 publicPrice_,
        uint256 maxSupply_,
        address[] memory payees_,
        uint256[] memory shares_,
        address platformAdmin_,
        address owner_,
        uint32 presaleMintingLimit_,
        uint32 publicMintingLimit_,
        bytes32 merkleRoot_
    ) external onlyOwner returns (address) {
        // Create the clone of the base contract
        address clone = baseContract.clone();

        // Call the interface to initialize the clone
        IStonesERC721(clone).initialize(
            name_,
            symbol_,
            uri_,
            presalePrice_,
            publicPrice_,
            maxSupply_,
            payees_,
            shares_,
            platformAdmin_,
            owner_,
            presaleMintingLimit_,
            publicMintingLimit_,
            merkleRoot_
        );

        // Push the clone to the owner's ERC721Contracts
        ERC721Contracts[msg.sender].push(clone);

        // Emit the event
        emit NewClone(clone, msg.sender);

        // Return the clone address
        return clone;
    }

    function changeBaseContract(address baseContract_) external onlyOwner {

        // Make sure the address is valid and not the same as before
        require(baseContract_ != address(0), "InvalidAddress");
        require(baseContract_ != baseContract, "Same address error");

        // Change the base contract
        baseContract = baseContract_;

        // Emit the event
        emit ImplementationERC721Changed(baseContract);
    }

    /**
     * @notice changeDefaultPlatformAdmin is used when the default admin address needs to be changed before creation of 721 address
     * @param newDefaultAdminAddress_ is the new address of the admin
     */
    function changeDefaultPlatformAdmin(address newDefaultAdminAddress_) public onlyOwner {
        require(newDefaultAdminAddress_ != address(0) || newDefaultAdminAddress_ != defaultPlatformAdmin, "Admin address is invalid");

        defaultPlatformAdmin = newDefaultAdminAddress_;
    }  
}
