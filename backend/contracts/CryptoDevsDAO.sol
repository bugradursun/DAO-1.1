// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

//interfaces:
//1st interface is for our nftmarketplace
//2nd interface is for our cryptodevs nft and only 2 functions

interface IFakeNFTMarketplace {
    function getPrice() external view returns (uint256);

    function available(uint256 _tokenId) external view returns (bool);

    function purchase(uint256 _tokenId) external payable;
}

interface ICryptoDevsNft {
    function balanceOf(address owner) external view returns (uint256);

    // returns a tokenId at given index for owner.
    function tokenOfOwnerByIndex(
        address owner,
        uint256 index
    ) external view returns (uint256);
}

contract CryptoDevsDAO is Ownable {
    struct Proposal {
        uint256 nftTokenId;
        uint256 deadline;
        uint256 yayVotes; //number of yes votes
        uint256 nayVotes; //number of no votes
        bool executed; //cant be executed before the deadline has been exceeded
        mapping(uint256 => bool) voters; //indicated whether that NFT has already been used to vote
    }

    enum Vote {
        YAY, //0
        NAY //1
    }
    mapping(uint256 => Proposal) public proposals; //uint256 for propsalId
    uint256 public numProposals;

    IFakeNFTMarketplace nftMarketplace; // nftMarketplace is interface instance
    ICryptoDevsNft cryptoDevsNFT; //cryptoDevsNFT is interface instance

    constructor(address _nftMarketplace, address _cryptoDevsNFT) payable {
        nftMarketplace = IFakeNFTMarketplace(_nftMarketplace);
        cryptoDevsNFT = ICryptoDevsNft(_cryptoDevsNFT);
    }

    /**
     * this modifier allows a fnc to be called if given
     * proposals deadline has been exceeded
     * and if proposal hasnt yet been executed
     * (zaman uzatildi+proposal islenmedi durumu)
     */
    modifier inactiveProposalOnly(uint256 proposalIndex) {
        require(
            proposals[proposalIndex].deadline <= block.timestamp,
            "DEADLINE_NOT_EXCEEDED"
        );
        require(
            proposals[proposalIndex].executed == false,
            "PROPOSAL_ALREADY_EXECUTED"
        );
        _;
    }

    //constructordakiler interface instance oldu
    modifier activeProposalOnly(uint256 proposalIndex) {
        require(
            proposals[proposalIndex].deadline > block.timestamp,
            "DEADLINE_EXCEEDED"
        );
        _;
    }

    modifier nftHolderOnly() {
        // allows a fnc to be called by someone who has minimum 1 cryptodevsnft
        require(cryptoDevsNFT.balanceOf(msg.sender) > 0, "NOT_A_DAO_MEMBER");
        _;
    }

    function createProposal(
        uint256 _nftTokenId
    ) external nftHolderOnly returns (uint256) {
        require(nftMarketplace.available(_nftTokenId), "NFT_NOT_FOR_SALE");
        Proposal storage proposal = proposals[numProposals];
        proposal.nftTokenId = _nftTokenId;

        proposal.deadline = block.timestamp + 5 minutes;
        numProposals++;

        return numProposals - 1; //returns proposal index !!
    }

    /**
     * @dev voteOnProposal allows a CryptoDevsNFT holder to cast their vote on an active proposal
     * @param  proposalIndex - index of the proposal to vote
     * @param vote - the type of vote they want to cast
     */
    function voteOnProposal(
        uint256 proposalIndex,
        Vote vote
    ) external nftHolderOnly activeProposalOnly(proposalIndex) {
        Proposal storage proposal = proposals[proposalIndex];

        uint256 voterNFTBalance = cryptoDevsNFT.balanceOf(msg.sender);
        uint256 numVotes = 0;

        for (uint256 i = 0; i < voterNFTBalance; i++) {
            uint256 tokenId = cryptoDevsNFT.tokenOfOwnerByIndex(msg.sender, i);
            if (proposal.voters[tokenId] == false) {
                numVotes++;
                proposal.voters[tokenId] = true;
            }
        }
        require(numVotes > 0, "ALREADY_VOTED");
        if (vote == Vote.YAY) {
            proposal.yayVotes += numVotes;
        } else {
            proposal.nayVotes += numVotes;
        }
    }

    function executeProposal(
        uint256 proposalIndex
    ) external nftHolderOnly inactiveProposalOnly(proposalIndex) {
        Proposal storage proposal = proposals[proposalIndex];
        if (proposal.yayVotes > proposal.nayVotes) {
            uint256 nftPrice = nftMarketplace.getPrice();
            require(address(this).balance >= nftPrice, "NOT_ENOUGH_FUNDS");
            nftMarketplace.purchase{value: nftPrice}(proposal.nftTokenId);
        }
        proposal.executed = true;
    }

    function withdrawEther() external onlyOwner {
        uint256 amount = address(this).balance; // bu kontrattaki eth
        require(amount > 0, "Nothing to withdraw");
        payable(owner()).transfer(amount);
    }

    /**
     * users should be able to transfer ETH directly from their wallet
     * to do that,add receive and fallback fncs
     */

    receive() external payable {}

    fallback() external payable {}
}
