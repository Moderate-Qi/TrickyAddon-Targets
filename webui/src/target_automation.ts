import { exec } from 'kernelsu-alt'
import { Cli } from './cli'
import { isDev } from './utils/dev'

export type TargetMode = 'auto' | 'generate' | 'hack'
export interface TargetAutomationState {
  mode: TargetMode
  auto_add: boolean
  target_count: number
  backup: boolean
  supported: boolean
  last_sync: string
}

export class TargetAutomation {
  #cli: Cli
  #preview: TargetAutomationState = {
    mode: 'generate', auto_add: true, target_count: 0,
    backup: true, supported: true, last_sync: '本机界面预览',
  }

  constructor(cli: Cli) { this.#cli = cli }

  async run(command: 'status' | 'configure' | 'apply' | 'restore', mode?: TargetMode, auto?: boolean): Promise<TargetAutomationState> {
    if (isDev()) {
      if (mode) this.#preview.mode = mode
      if (auto !== undefined) this.#preview.auto_add = auto
      if (command === 'restore') this.#preview.auto_add = false
      return { ...this.#preview }
    }
    const base = await this.#cli.getBasePath()
    const args: string[] = [command]
    if (mode) args.push(mode)
    if (auto !== undefined) args.push(auto ? '1' : '0')
    const result = await exec(`sh '${base}/target-automation.sh' ${args.join(' ')}`)
    if (result.errno !== 0) throw new Error(result.stderr.trim() || '目标配置操作失败')
    return JSON.parse(result.stdout.trim()) as TargetAutomationState
  }
}
