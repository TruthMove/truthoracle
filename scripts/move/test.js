require("dotenv").config();

const cli = require("@aptos-labs/ts-sdk/dist/common/cli/index.js");

async function test() {
  const move = new cli.Move();

  await move.test({
    packageDirectoryPath: "move",
    namedAddresses: {
      message_board_addr: "0xb7d3763b821401656f0d23a8ff0ae4567b9f5f06973eafbc142f5e832405f262",
    },
  });
}
test();
