// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract AuctionCreator{
    Auction[] public auctions;

    function createAuction() public{
        Auction newAuction = new Auction(msg.sender);
        auctions.push(newAuction);
    }
}

contract Auction{
    address payable public owner;

    //In the auction it requires a starting and an ending time 
    uint public startBlock;
    uint public endBlock;

    //To store the data and the description of the prduct it is not possible to do that on blockchain so we use IPFS for that
    string public ipfsHash;

    //To define the state of the auction if it is open or not
    enum State {Started, Running, Ended, Cancelled}
    State public auctionState;

    //This is the selling price and the price at which the auction was closed 
    uint public highestBindingBid;
    address payable public highestBidder;

    //We also create a mapping to store all the bids 
    mapping(address => uint256) public bids;
    uint bidIncrement;

    constructor(address eoa){
        owner = payable(eoa);
        auctionState = State.Running;
        //Now here to intialise the start and the end block we are going to use the block number rather than using the blocktimestamp because that can be manipulated
        startBlock = block.number; //This is for making the auction start rightaway we can set it for a time later also
        endBlock = startBlock + 40320; //This will make sure the auction ends one week after we had started the auction
        ipfsHash = "";
        bidIncrement = 100;
    }

    //We need to make sure the owner cannot placeBid so we now creating a function modifier as notOwner
    modifier notOwner(){
        require(msg.sender != owner);
        _;
    }

    modifier afterStart(){
        require(block.number >= startBlock);
        _;
    }

    modifier beforeEnd(){
        require(block.number <= endBlock);
        _;
    }

    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }

    //This function is to return the minimum value among the 2 inputs given
    function min(uint a , uint b) pure internal returns(uint){
        if(a<=b){
            return a;
        }else{
            return b;
        }
    }

    //Now we are going to declare a function through which the user can place a bid and in this we make sure owner cannot call the function and we can only call it after the auction starts and before it ends
    function placeBid() public payable notOwner afterStart beforeEnd{
        require(auctionState == State.Running); //Make sure the auction is still running
        require(msg.value >= 100); //We need to make sure minimum bidding amount is 100 wei

        uint currentBid = bids[msg.sender] + msg.value;
        require(currentBid > highestBindingBid); //This is necessary because or else there would nothing to be done in that situation 
        bids[msg.sender] = currentBid;

        if(currentBid <= bids[highestBidder]){
            highestBindingBid = min(currentBid + bidIncrement , bids[highestBidder]);
        }else{
            highestBindingBid = min(currentBid,bids[highestBidder]+bidIncrement);
            highestBidder = payable(msg.sender);
        }
    }

    //Incase of an emergency the owner should have an option to cancel the auction in case of an emergency
    function cancelAuction() public view onlyOwner{
        auctionState == State.Cancelled;
    }

    //We dont proactively send back the funds to the users that did not win the auction we will use the withdrwal pattern instead it helps us avoid the re entrance attacks that could cause unexpected behaviour including losses
    function finalizeAuction() public{
        require(auctionState == State.Cancelled || block.number > endBlock); // To make sure they can call the withdraw function if the auction is cancelled or the auction has ended
        require(msg.sender == owner || bids[msg.sender] > 0); //To make sure the owner is calling or a bidder is calling the auction

        address payable recepient;
        uint value;
        if(auctionState == State.Cancelled){
            recepient = payable(msg.sender);
        }else { 
            //This is conditon where auction ended and not cancelled
            if(msg.sender == owner){
                recepient = owner;
                value = highestBindingBid;
            }else{
                //This is the bidder
                if(msg.sender == highestBidder){
                    recepient = highestBidder;
                    value = bids[highestBidder] - highestBindingBid;
                }else{
                    recepient =  payable (msg.sender);
                    value = bids[msg.sender];
                }
            }          
        }
        //Reseting the number of bids to 0 so that he cannot this function again and again
        bids[recepient] = 0;

        //Sending the value to the recepient
        recepient.transfer(value);
    }
}
