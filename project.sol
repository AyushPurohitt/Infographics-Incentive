// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract InfographicsIncentive is ERC721, ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    struct Infographic {
        string ipfsHash;
        address creator;
        uint256 likes;
        uint256 shares;
        uint256 rewardsClaimed;
        bool isVerified;
        bool exists;
        mapping(address => bool) hasLiked;
        mapping(address => bool) hasShared;
    }

    mapping(uint256 => Infographic) public infographics;
    uint256 public rewardPerLike = 0.001 ether;
    uint256 public rewardPerShare = 0.002 ether;
    uint256 public verificationFee = 0.01 ether;

    event InfographicCreated(uint256 indexed tokenId, address creator, string ipfsHash);
    event InfographicLiked(uint256 indexed tokenId, address liker);
    event InfographicShared(uint256 indexed tokenId, address sharer);
    event RewardsClaimed(uint256 indexed tokenId, address creator, uint256 amount);

    constructor() ERC721("Infographics Incentive", "INFO") Ownable(msg.sender) {}

    function exists(uint256 tokenId) public view returns (bool) {
        return infographics[tokenId].exists;
    }

    function createInfographic(string memory ipfsHash) external payable {
        require(msg.value >= verificationFee, "Insufficient verification fee");
        
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        
        Infographic storage newInfographic = infographics[newTokenId];
        newInfographic.ipfsHash = ipfsHash;
        newInfographic.creator = msg.sender;
        newInfographic.isVerified = false;
        newInfographic.exists = true;
        
        _safeMint(msg.sender, newTokenId);
        
        emit InfographicCreated(newTokenId, msg.sender, ipfsHash);
    }

    function verifyInfographic(uint256 tokenId) external onlyOwner {
        require(exists(tokenId), "Infographic does not exist");
        infographics[tokenId].isVerified = true;
    }

    function likeInfographic(uint256 tokenId) external {
        require(exists(tokenId), "Infographic does not exist");
        require(infographics[tokenId].isVerified, "Infographic not verified");
        require(!infographics[tokenId].hasLiked[msg.sender], "Already liked");
        
        infographics[tokenId].likes++;
        infographics[tokenId].hasLiked[msg.sender] = true;
        
        emit InfographicLiked(tokenId, msg.sender);
    }

    function shareInfographic(uint256 tokenId) external {
        require(exists(tokenId), "Infographic does not exist");
        require(infographics[tokenId].isVerified, "Infographic not verified");
        require(!infographics[tokenId].hasShared[msg.sender], "Already shared");
        
        infographics[tokenId].shares++;
        infographics[tokenId].hasShared[msg.sender] = true;
        
        emit InfographicShared(tokenId, msg.sender);
    }

    function claimRewards(uint256 tokenId) external nonReentrant {
        require(exists(tokenId), "Infographic does not exist");
        require(infographics[tokenId].creator == msg.sender, "Not the creator");
        
        Infographic storage infographic = infographics[tokenId];
        
        uint256 likeRewards = (infographic.likes * rewardPerLike);
        uint256 shareRewards = (infographic.shares * rewardPerShare);
        uint256 totalRewards = likeRewards + shareRewards - infographic.rewardsClaimed;
        
        require(totalRewards > 0, "No rewards to claim");
        require(address(this).balance >= totalRewards, "Insufficient contract balance");
        
        infographic.rewardsClaimed += totalRewards;
        payable(msg.sender).transfer(totalRewards);
        
        emit RewardsClaimed(tokenId, msg.sender, totalRewards);
    }

    function updateRewardRates(uint256 newLikeReward, uint256 newShareReward) external onlyOwner {
        rewardPerLike = newLikeReward;
        rewardPerShare = newShareReward;
    }

    function updateVerificationFee(uint256 newFee) external onlyOwner {
        verificationFee = newFee;
    }

    receive() external payable {}
}