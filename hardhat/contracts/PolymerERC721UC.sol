//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import "./base/UniversalChanIbcApp.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract PolymerERC721UC is UniversalChanIbcApp, ERC721 {
    uint256 public currentTokenId = 0;
    string public tokenURIC4 =
        "https://gateway.ipfsscan.io/ipfs/QmPGHLqdsDAGJY7KHF8ZifjQvvjSPFKqsGT1M5axu1VcWv?filename=QmZu7WiiKyytxwwKSwr6iPT1wqCRdgpqQNhoKUyn1CkMD3.json";


    IERC20 public acceptTokenAddress;
    uint256 public randomizerPrice = 10*10**18; 

    event MintAckReceived(address receiver, uint256 tokenId, string message);
    event NFTAckReceived(address voter, address recipient, uint256 voteId);

    enum NFTType {
        POLY1,
        POLY2,
        POLY3,
        POLY4
    }

    mapping(uint256 => NFTType) public tokenTypeMap;
    mapping(NFTType => string) public tokenURIs;
    mapping(NFTType => uint256[]) public typeTokenMap; 


    
    constructor(address _middleware) UniversalChanIbcApp(_middleware) ERC721("nftsWithPts", "ptNFT") {
        tokenURIs[NFTType.POLY1] = "https://gateway.ipfsscan.io/ipfs/QmX9LckCJtBpi1WU43vL6Xkxz1ZcuvUKNrWu6bZCnuPyqS";
        tokenURIs[NFTType.POLY2] = "https://gateway.ipfsscan.io/ipfs/QmVtbtSMkx5JdgAYn1rj5Wsx9w3Pv9zEUDNrwfmJE6homL";
        tokenURIs[NFTType.POLY3] = "https://gateway.ipfsscan.io/ipfs/QmdkPqEKZ8tA6SmCizfcTcTCfqagUcYUT1CueZBaCC9UZn";
        tokenURIs[NFTType.POLY4] = "https://gateway.ipfsscan.io/ipfs/QmUk7oFiMdkzSh6vQBdtS12WrvYY2ycVE6MXRAmDjxFDYT";
        mint(msg.sender, NFTType.POLY4);
    }

    function setAcceptTokenAddress(address _erc20TokenAddress) public {
        acceptTokenAddress = IERC20(_erc20TokenAddress);
    }



    function mint(address recipient, NFTType pType) internal returns (uint256) {
        currentTokenId += 1;
        uint256 tokenId = currentTokenId;
        tokenTypeMap[tokenId] = pType;
        typeTokenMap[pType].push(tokenId);
        _safeMint(recipient, tokenId);
        return tokenId;
    }

    function randomMint(address recipient) public {
        require(msg.sender == recipient, "you need to mint yourself!");
        require(acceptTokenAddress.balanceOf(msg.sender) >= randomizerPrice, "pts too low to mint a randomizer!");
        // require()
        // acceptTokenAddress

        acceptTokenAddress.transferFrom(msg.sender, address(this), randomizerPrice);
        uint256 random = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % 100;
        NFTType pType = NFTType.POLY1;
        if (random >= 50 && random < 75) {
            pType = NFTType.POLY2;
        } else if (random >= 75 && random < 95) {
            pType = NFTType.POLY3;
        } else if (random >= 95) {
            pType = NFTType.POLY4;
        }
        mint(recipient, pType);
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        revert("Transfer not allowed");
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);
        return tokenURIs[tokenTypeMap[tokenId]];
    }

    function updateTokenURI(string memory _newTokenURI) public {
        tokenURIC4 = _newTokenURI;
    }

    function getTokenId() public view returns (uint256) {
        return currentTokenId;
    }

    function crossChainMint(address destPortAddr, bytes32 channelId, uint64 timeoutSeconds, NFTType tokenType)
        external
    {
        bytes memory payload = abi.encode(msg.sender, tokenType);
        uint64 timeoutTimestamp = uint64((block.timestamp + timeoutSeconds) * 1000000000);

        // Check if they have enough Polymer Testnet Tokens to mint the NFT
        // If not Revert

        // Burn the Polymer Testnet Tokens from the sender

        IbcUniversalPacketSender(mw).sendUniversalPacket(
            channelId, IbcUtils.toBytes32(destPortAddr), payload, timeoutTimestamp
        );
    }

    /**
     * @dev Packet lifecycle callback that implements packet receipt logic and returns and acknowledgement packet.
     *      MUST be overriden by the inheriting contract.
     *
     * @param channelId the ID of the channel (locally) the packet was received on.
     * @param packet the Universal packet encoded by the source and relayed by the relayer.
     */
    function onRecvUniversalPacket(bytes32 channelId, UniversalPacket calldata packet)
        external
        override
        onlyIbcMw
        returns (AckPacket memory ackPacket)
    {
        recvedPackets.push(UcPacketWithChannel(channelId, packet));

        (address _caller, NFTType tokenType) = abi.decode(packet.appData, (address, NFTType));

        uint256 tokenId = mint(_caller, tokenType);

        return AckPacket(true, abi.encode(_caller, tokenId));
    }

    /**
     * @dev Packet lifecycle callback that implements packet acknowledgment logic.
     *      MUST be overriden by the inheriting contract.
     *
     * @param channelId the ID of the channel (locally) the ack was received on.
     * @param packet the Universal packet encoded by the source and relayed by the relayer.
     * @param ack the acknowledgment packet encoded by the destination and relayed by the relayer.
     */
    function onUniversalAcknowledgement(bytes32 channelId, UniversalPacket memory packet, AckPacket calldata ack)
        external
        override
        onlyIbcMw
    {
        ackPackets.push(UcAckWithChannel(channelId, packet, ack));

        // decode the counter from the ack packet
        (address caller, uint256 tokenId) = abi.decode(ack.data, (address, uint256));

        emit MintAckReceived(caller, tokenId, "NFT minted successfully");
    }

    /**
     * @dev Packet lifecycle callback that implements packet receipt logic and return and acknowledgement packet.
     *      MUST be overriden by the inheriting contract.
     *      NOT SUPPORTED YET
     *
     * @param channelId the ID of the channel (locally) the timeout was submitted on.
     * @param packet the Universal packet encoded by the counterparty and relayed by the relayer
     */
    function onTimeoutUniversalPacket(bytes32 channelId, UniversalPacket calldata packet) external override onlyIbcMw {
        timeoutPackets.push(UcPacketWithChannel(channelId, packet));
        // do logic
    }
}