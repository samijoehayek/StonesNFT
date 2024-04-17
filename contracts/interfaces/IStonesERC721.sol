// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/// @notice ERC20 interface
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @dev This is an interface whereby we can interact with the base ERC20 contract
interface IStonesERC721 is IERC721 {
    function mint(address account, uint256 amount) external payable;
    function burn(address account, uint256 amount) external;
    function initialize(
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
    ) external;
    function pause() external;
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function owner() external view returns (address);
}
