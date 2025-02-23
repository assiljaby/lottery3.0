include .env
deploy:
	@forge script ./script/deployFundMe.s.sol --rpc-url ${SEPOLIA_RPC_URL} --broadcast --private-key ${PRIVATE_KEY}
anvil-deploy:
	@forge script ./script/deployFundMe.s.sol --rpc-url ${ANVIL_URL} --broadcast --private-key ${ANVIL_PRIVATE_KEY}
test-fork:
	@forge test --fork-url ${SEPOLIA_RPC_URL}