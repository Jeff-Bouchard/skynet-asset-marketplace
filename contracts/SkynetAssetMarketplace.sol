pragma solidity 0.4.24;

// Chainlink
import "../node_modules/chainlink/contracts/ChainlinkClient.sol";

// OpenZeppelin
import "../node_modules/openzeppelin-solidity/contracts/ownership/Ownable.sol";

// Storage
import "./storage/SyStorage.sol";
import "./storage/SyConstants.sol";


contract SkynetAssetMarketplace is ChainlinkClient, Ownable, SyStorage, SyConstants {
    mapping(address => uint256) private betsTrue;
    mapping(address => uint256) private betsFalse;
    uint256 public totalBetTrue;
    uint256 public totalBetFalse;

    uint256 private oraclePaymentAmount;
    bytes32 private jobId;

    bool public resultReceived;
    bool public result;

    // @dev - Assign responsed value from CoinMarketCap
    uint256 public currentPrice;

    // @dev - Current assetId which is used when create listing asset 
    uint256 public currentAssetId;

    constructor(
        address _link,
        address _oracle,
        bytes32 _jobId,
        uint256 _oraclePaymentAmount
        //string _coin,
        //string _market
    )
    Ownable()
    public
    {
        setChainlinkToken(_link);
        setChainlinkOracle(_oracle);
        jobId = _jobId;
        oraclePaymentAmount = _oraclePaymentAmount;
    }

    function bet(bool betOutcome) external payable
    {
        require(!resultReceived, "You cannot bet after the result has been received.");
        if (betOutcome)
        {
            betsTrue[msg.sender] += msg.value;
            totalBetTrue += msg.value;
        }
        else
        {
            betsFalse[msg.sender] += msg.value;
            totalBetFalse += msg.value;
        }
    }

    function withdraw() external
    {
        require(resultReceived, "You cannot withdraw before the result has been received.");
        if (result)
        {
            msg.sender.transfer(((totalBetTrue + totalBetFalse) * betsTrue[msg.sender]) / totalBetTrue);
            betsTrue[msg.sender] = 0;
        }
        else
        {
            msg.sender.transfer(((totalBetTrue + totalBetFalse) * betsFalse[msg.sender]) / totalBetFalse);
            betsFalse[msg.sender] = 0;
        }
    }

    // You probably do not want onlyOwner here
    // But then, you need some mechanism to prevent people from spamming this
    function requestResult(string _coin, string _market) external returns (bytes32 requestId)  //@notice - Remove onlyOwner
    {
        //require(!resultReceived, "The result has already been received.");
        Chainlink.Request memory req = buildChainlinkRequest(jobId, this, this.fulfill.selector);
        // req.add("low", "1");
        // req.add("high", "6");
        // req.add("copyPath", "random_number");

        // @dev - request path of CoinMarketCap 
        req.add("sym", _coin);
        req.add("convert", _market);
        string[] memory path = new string[](5);
        path[0] = "data";
        path[1] = _coin;
        path[2] = "quote";
        path[3] = _market;
        path[4] = "price";
        req.addStringArray("copyPath", path);
        req.addInt("times", 1000000);   //@dev - i.e). Rate of Siacoin(SC) is 0.001009 USD. That's why it specify 1000000 times 

        requestId = sendChainlinkRequestTo(chainlinkOracleAddress(), req, oraclePaymentAmount);
    }

    function getBetAmount(bool outcome) external view returns (uint256 betAmount)
    {
        if (outcome)
        {
            betAmount = betsTrue[msg.sender];
        }
        else
        {
            betAmount = betsFalse[msg.sender];
        }
    }

    function fulfill(bytes32 _requestId, uint256 _price)
    public
    recordChainlinkFulfillment(_requestId)
    {
        resultReceived = true;

        currentPrice = _price;
        // if (data == 6)
        // {
        //     result = true;
        // }
        // else
        // {
        //     result = false;
        // }
    }



    /////////////////////
    /// @dev - Save listing assets which are uploaded on Skynet in blockchain and that is listed SkynetAssetMarketplace
    /////////////////////
    function createListingAsset(
        address _assetOwnerAddr,
        string _hashOfAssetOnSkynet,
        uint256 _sellingPriceBySiacoin
    ) public returns (bool) {
        ListingAsset storage listingAsset = listingAssets[currentAssetId];
        listingAsset.assetId = currentAssetId;
        listingAsset.assetOwnerAddr = _assetOwnerAddr;
        listingAsset.hashOfAssetOnSkynet = _hashOfAssetOnSkynet;
        listingAsset.sellingPriceBySiacoin = _sellingPriceBySiacoin;

        emit CreateListingAsset(listingAsset.assetId, 
                                listingAsset.assetOwnerAddr, 
                                listingAsset.hashOfAssetOnSkynet, 
                                listingAsset.sellingPriceBySiacoin);

        //@dev - currentAssetId is counted up to next assetId 
        currentAssetId ++;
    }
    

}
