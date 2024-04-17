// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Import the ERC721 Upgradeable contract from the OpenZeppelin Contracts library
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// Import the Ownable Upgradeable contract from the OpenZeppelin Contracts library
import "@openzeppelin/contracts/access/Ownable.sol";
// Import the Initializable contract from the OpenZeppelin Contracts library
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
/// @notice Pausable Contract pattern
import "@openzeppelin/contracts/utils/Pausable.sol";
/// @notice libraries
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
/// @notice Payment Splitter
import "./paymentSplitter/PaymentSplitter.sol";

contract Stones is Initializable, ERC721, Pausable, PaymentSplitter {
    /// @notice Defining the type of Addresses for extended functionality
    using Address for address;

    /// @notice using MerkleProof library to define the type of bytes32
    using MerkleProof for bytes32[];

    /// @notice Enum representing the minting phases
    enum Phase {
        Presale,
        Public
    }

    /// @notice Mint event to be emitted upon NFT mint by any user
    event UserMint(
        address indexed to,
        uint256 amount
    );

    /// @notice Phase change event to emitted when the phase is changed
    event PhaseChange(
        Phase phase
    );

    /// @notice Phase change event to emitted when the phase is changed
    event PhaseChange(
        Phase phase, 
        uint256[] mintPrice, 
        uint256 mintingLimit
    );

    // Errors thrown by the contract
    /// @notice Transaction Fallback Disabled
    error FallbackDisabled();

    /// @notice the current phase of the miniting
    Phase private phase;

    /// @notice Is Base Contract flag
    bool public isBase;
    /// @notice Token name
    string private tokenName;
    /// @notice Token symbol
    string private tokenSymbol;
    /// @notice Base URI for the token
    string private baseURI;
    /// @notice Presale price
    uint256 private presalePrice;
    /// @notice Public sale price
    uint256 private publicPrice;
    /// @notice Token ID counter
    uint256 private tokenIdCounter;
    /// @notice Maximum supply of the tokens
    uint256 public maxSupply;
    /// @notice Address of the platform admin
    address public platformAdmin;
    /// @notice Address of the owner
    address public owner;
    /// @notice Limit of minting for the presale
    uint32 public presaleMintingLimit;
    /// @notice Limit of minting for the public sale
    uint32 public publicMintingLimit;
    /// @notice merkle root
    bytes32 private merkleRoot;

    /// @notice indicates the amount of mints per user
    mapping(address => mapping(Phase => uint256)) public mintsPerUser;

    // Modifier to check if the function caller is a platform admin
    modifier onlyPlatformAdmin() {
        require(
            msg.sender == platformAdmin,
            "Only platform admin can call this function"
        );
        _;
    }

    // Modifier to check if the function caller is the owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    /**
     * @notice constructor
     * @param isBase_ is the boolean that defines if it is the base contract
     * @param name_ is the name_ of the base contract
     * @param symbol_ is the symbol of the main contract
     **/
    constructor(
        bool isBase_,
        string memory name_,
        string memory symbol_
    ) ERC721(name_, symbol_) {
        isBase = isBase_;
    }

    /**
     * @notice Initialize function used in the launchpad
     * @param name_ is the name_ of the cloned contract
     * @param symbol_ is the symbol of the cloned contract
     * @param uri_ is the uri of the metadata URI
     * @param presalePrice_ is the price of the presale
     * @param publicPrice_ is the price of the public sale
     * @param maxSupply_ is the maximum supply of the tokens
     * @param payees_ is the array of addresses to receive the payments
     * @param shares_ is the array of shares for the payees
     * @param platformAdmin_ is the address of the platform admin
     * @param owner_ is the address of the owner
     * @param presaleMintingLimit_ is the limit of minting for the presale
     * @param publicMintingLimit_ is the limit of minting for the public sale
     * @param merkleRoot_ is the array of merkle roots
     */

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
    ) external initializer {
        // Make sure parameter requirements are met
        require(!isBase, "This is a base contract");

        // Check for contract name, symbol, and uri
        require(bytes(name_).length > 0, "Name is required");
        require(bytes(symbol_).length > 0, "Symbol is required");
        require(bytes(uri_).length > 0, "URI is required");

        // Check for the max supply being greater than 0
        require(maxSupply_ > 0, "Max supply must be greater than 0");

        // Check for the address of the owner being valid
        require(owner_ != address(0), "Owner is required");

        // Check for the address of the platform admin being valid
        require(platformAdmin_ != address(0), "Platform admin is required");

        // Check for the minting limit not being greater than the max supply
        require(
            (presaleMintingLimit_ <= maxSupply_ ||
                publicMintingLimit_ <= maxSupply_),
            "Presale and public minting limit must be less than or equal to max supply"
        );

        // Set variables for the contract
        tokenName = name_;
        tokenSymbol = symbol_;
        baseURI = uri_;
        presalePrice = presalePrice_;
        publicPrice = publicPrice_;
        maxSupply = maxSupply_;
        platformAdmin = platformAdmin_;
        presaleMintingLimit = presaleMintingLimit_;
        publicMintingLimit = publicMintingLimit_;
        merkleRoot = merkleRoot_;

        // Set the owner of the contract
        owner = owner_;

        // Set the payees and shares for the PaymentSplitter
        initializePaymentSplitter(payees_, shares_);
    }

    /**
     * @notice mint is a function that allows users to mint tokens
     * @param to_ represents the address the user is minting to
     * @param amount_ represents the amount of tokens to mint
     * @param proof_ represents the proof of the user being allowed to mint
    */
    function mint(
        address to_,
        uint256 amount_,
        bytes32[] memory proof_
    ) external payable whenNotPaused {
        // Make sure the address is valid
        require(to_ != address(0), "InvalidAddress");

        // Make sure the amount is less tan the max supply
        require(amount_ <= maxSupply, "Amount exceeds max supply");

        // Make sure that after minting the amount minted is less than the max supply
        require(
            totalSupply() + amount_ <= maxSupply,
            "Minting amount exceeds max supply"
        );
        // Check if the user limit is not exceeded
        checkUserLimit(to_, amount_);

        // Check if the phase is presale
        if (phase == Phase.Presale) {
            // Check if the user is allowed to mint
            isAllowedToMint(proof_);

            // Check if the amount sent is correct
            require(
                msg.value == presalePrice * amount_,
                "Incorrect amount sent"
            );
        } else {
            // Check if the amount sent is correct
            require(msg.value == publicPrice * amount_, "Incorrect amount sent");
        }

        // Mint the tokens
        _mint(to_, amount_);
        // Increment the mints per user
        mintsPerUser[to_][phase] += amount_;
        tokenIdCounter += amount_;

        // Emit the UserMint event
        emit UserMint(to_, amount_);
    }

    // Function to disable sending the ether to the contract
    receive() external payable override {
        revert FallbackDisabled();
    }

    // Function to disable sending the ether to the contract
    fallback() external payable {
        revert FallbackDisabled();
    }

    // Function to pause the contract by the owner
    function pause() external onlyOwner {
        _pause();
    }

    // Function to unpause the contract by the owner
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice isAllowedToMint is a function that checks if the user is allowed to mint
     * @param proof_ is the proof of the user being allowed to mint
     */
    // Middleware function to check if the user is allowed to mint
    function isAllowedToMint(
        bytes32[] memory proof_
    ) internal view returns (bool) {
        require(
            MerkleProof.verify(
                proof_,
                merkleRoot,
                keccak256(abi.encodePacked(msg.sender))
            ),
            "User not allowed to mint"
        );
        return true;
    }

    /**
     * @notice setPhase is a function that allows the owner to set the phase of the minting
     * @param phase_ is the phase to set
     */
    function setPhase(Phase phase_) external onlyOwner {
        // Check if the phase is valid
        require(
            phase_ == Phase.Presale || phase_ == Phase.Public,
            "Invalid phase"
        );
        phase = phase_;

        // Emit the PhaseChange event
        emit PhaseChange(phase_);
    }

    /**
     * @notice changeMintingLimit is a function that allows the owner to change the minting limit per phase
     * @param phase_ is the phase to set
     * @param mintingLimit_ is the limit of minting
    */
    function changeMintingLimit(
        uint32 mintingLimit_,
        Phase phase_
    ) external onlyOwner {
        // Check if the phase is valid
        require(
            phase_ == Phase.Presale || phase_ == Phase.Public,
            "Invalid phase"
        );
        // Check if the minting limit is less than or equal to the max supply
        require(
            mintingLimit_ <= maxSupply,
            "Presale or public minting limit must be less than or equal to max supply"
        );
        // If the phase chosen is presale set it in the presaleMintingLimit, same for public
        if (phase_ == Phase.Presale) {
            presaleMintingLimit = mintingLimit_;
        } else {
            publicMintingLimit = mintingLimit_;
        }
    }

    /**
     * @notice changeMintPrice is a function that allows the owner to change the minting price per phase
     * @param tokenPrice_ is the price of the token
     * @param phase_ is the phase to set
    */
    function changePrice(uint256 tokenPrice_, Phase phase_) external onlyOwner {
        // Check if the phase is valid
        require(
            phase_ == Phase.Presale || phase_ == Phase.Public,
            "Invalid phase"
        );
        // If the phase chosen is presale set it in the presalePrice, same for public
        if (phase_ == Phase.Presale) {
            presalePrice = tokenPrice_;
        } else {
            publicPrice = tokenPrice_;
        }
    }

    /**
     * @notice checkUserLimit is a function that checks if the user limit is exceeded
     * @param to_ is the address of the user
     * @param amount_ is the amount of tokens to mint
     */
    function checkUserLimit(
        address to_,
        uint256 amount_
    ) public view returns (bool) {
        if (phase == Phase.Presale) {
            require(
                mintsPerUser[to_][phase] + amount_ <= presaleMintingLimit,
                "User limit exceeded for presale phase"
            );
            return true;
        } else {
            require(
                mintsPerUser[to_][phase] + amount_ <= publicMintingLimit,
                "User limit exceeded for this public phase"
            );
            return true;
        }
    }

    /**
     * @notice getPhase is a getter function that returns the phase
     */
    function getPhase() public view returns (Phase) {
        return phase;
    }

    /**
     * @notice getTicketPrice is a getter function that returns the price of the token
     * @param phase_ is the phase to get the price for
     */
    function getTicketPrice(Phase phase_) public view returns (uint256) {
        if (phase_ == Phase.Presale) {
            return presalePrice;
        } else {
            return publicPrice;
        }
    }

    /// @notice returns name of token
    function name() public view override returns (string memory) {
        return tokenName;
    }

    /// @notice returns symbol of token
    function symbol() public view override returns (string memory) {
        return tokenSymbol;
    }

    /// @notice returns base URI of token
    function getBaseURI() public view virtual returns (string memory) {
        return baseURI;
    }

    /// @notice returns the total supply of the token minted
    function totalSupply() public view returns (uint256) {
        return tokenIdCounter;
    }
}
