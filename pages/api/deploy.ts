import { ChildProcess, spawn } from "child_process"
import { closeSync, openSync } from "fs"
import rateLimit from "lib/ratelimit"
import type { NextApiRequest, NextApiResponse } from "next"

//set DEPLOY_SCRIPT and DEPLOY_TOKEN in .env
//DEPLOY_TOKEN is optional and corresponds to gitlab's X-Gitlab-Token header

const limiter = rateLimit({
  interval: 60 * 1000, // 60 seconds - adjust to approximate deployment time
  uniqueTokenPerInterval: 1, // Max users per second
})
var child = null as ChildProcess | null //prevents multiple deployment scripts from running concurrently

export default async function handler(
  _req: NextApiRequest,
  res: NextApiResponse
) {
  try {
    await limiter.check(res, 2, "CACHE_TOKEN") // 1 request within interval (not sure why the option is n-1)
    if (
      !process.env.DEPLOY_TOKEN ||
      process.env.DEPLOY_TOKEN == _req.headers["x-gitlab-token"] //"x-hub-signature-256" for github
    ) {
      if (!child) {
        console.log("Starting deployment")
        const logPipe = openSync(String("last_deploy.log"), "w") //perhaps redundant with pm2 logs
        child = spawn(String(process.env.DEPLOY_SCRIPT), [], {
          shell: true, //windows compatibility
          //detached: true,  //not needed with pm2 using the --no-treekill flag
          stdio: [logPipe, logPipe, logPipe],
        })
        child?.stdout?.setEncoding("utf8")
        child?.stdout?.on("data", function (data) {
          console.log(data) //logs to pm2
        })
        child.on("close", function () {
          console.log("Deploy script finished")
          closeSync(logPipe)
          child = null
        })
      } else {
        console.error("A deployment is already running!")
        return res
          .status(429)
          .json({ error: "A deployment is already running!" })
      }
    } else {
      console.error("Invalid deployment token!")
      return res.status(403).json({ error: "Invalid deployment token!" })
    }

    res.status(200).json({ deploying: true })
  } catch {
    console.error("Rate limit exceeded")
    res.status(429).json({ error: "Rate limit exceeded" })
  }
}
