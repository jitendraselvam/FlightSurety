import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';

var cors = require('cors');

const flights = [
	{ "id": 0, "name": "AS2345" },
	{ "id": 1, "name": "SW7897" },
	{ "id": 2, "name": "AA8792" },
	{ "id": 3, "name": "UA01" },
	{ "id": 4, "name": "DELTA34" },
	{ "id": 5, "name": "SPI8797" },
	{ "id": 6, "name": "FRON235" },
	{ "id": 7, "name": "MI5657" },
]


let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
//let flightSuretyData = new web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);

const ORACLES_COUNT = 20;
const ORACLES_ACCOUNT_OFFSET = 20; // Accounts 0 to 8 are reserved for owner, airlines and passengers
let oracles = [];


let eventIndex = null;


web3.eth.getAccounts((error, accounts) => {
	let owner = accounts[0];
	initOracles(accounts);

});
function initOracles(accounts) {
		
		for(let a=ORACLES_ACCOUNT_OFFSET; a<ORACLES_COUNT + ORACLES_ACCOUNT_OFFSET; a++) {
			flightSuretyApp.methods.registerOracle().send({from: accounts[a], value: web3.utils.toWei("1",'ether'), gas: 4500000}, (error, result) => {
			if(error) {
				console.log(error);
			}
			else {
				flightSuretyApp.methods.getMyIndexes().call({from: accounts[a]}, (error, result) => {
				if (error) {
					console.log(error);
				}
				else {
					let oracle = {address: accounts[a], index: result};
					console.log(`Oracle: ${JSON.stringify(oracle)}`);
					oracles.push(oracle);
				}
				});
			}
			});
		}
	console.log("Oracles registered");
	init();

	flightSuretyApp.events.SubmitOracleResponse({
		fromBlock: "latest"
	}, function (error, event) {
		if (error) {
			console.log(error)
		}
		console.log(event);

		let airline = event.returnValues.airline;
		let flight = event.returnValues.flight;
		let timestamp = event.returnValues.timestamp;
		let indexes = event.returnValues.indexes;
		let statusCode = event.returnValues.statusCode;

		for (let a = 0; a < oracles.length; a++) {
			console.log("Oracle loop ", a);
			flightSuretyApp.methods
				.submitOracleResponse(indexes, airline, flight, timestamp, statusCode)
				.send({
					from: oracles[a]
				}).then(result => {
					console.log(result);
				}).catch(err => {
					console.log("Oracle did not respond: " + err);

				});
		}

	});

	registerEvents();
}


function registerEvents() {
	try {

		flightSuretyApp.events.OracleRequest({
			fromBlock: 0
		}, function (error, event) {
			if (error) console.log(error)
			eventIndex = event.returnValues.index;
			console.log(event)
		});

		flightSuretyApp.events.RegisterAirline({
			fromBlock: 0
		}, function (error, event) {
			if (error) console.log(error)
			console.log(event)
		});

		flightSuretyApp.events.AirlinesFunded({
			fromBlock: 0
		}, function (error, event) {
			if (error) console.log(error)
			console.log(event)
		});

		flightSuretyApp.events.InsurancePurchased({
			fromBlock: 0
		}, function (error, event) {
			if (error) console.log(error)
			console.log(event)
		});

		flightSuretyApp.events.CreditInsurees({
			fromBlock: 0
		}, function (error, event) {
			if (error) console.log(error)
			console.log(event)
		});


		flightSuretyApp.events.WithdrawCompleted({
			fromBlock: 0
		}, function (error, event) {
			if (error) console.log(error)
			console.log(event)
		});

		flightSuretyApp.events.OracleReport({
			fromBlock: 0
		}, function (error, event) {
			if (error) console.log(error)
			console.log(event)
		});

	} catch(err) {
		console.log(err.message);
	}
}

const app = express();

function init() {
	app.get('/api', (req, res) => {
		res.send({
			message: 'An API for use with your Dapp!'
		})
	})

	app.get('/flights', (req, res) => {
		res.json({
			result: flights
		})
	})

	app.get('/eventIndex', (req, res) => {
		res.json({
			result: eventIndex
		})
	})

}

app.use(cors());


export default app;


