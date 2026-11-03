import type { MdDialog, MdSwitch, MdRadio, MdFilledButton, MdOutlinedButton } from '@material/web/all'
import { TargetAutomation } from '../target_automation'
import type { TargetMode, TargetAutomationState } from '../target_automation'
import { AppList } from '../app_list/app_list'
import { Snackbar } from '../snackbar/snackbar'
import { applyDialogAnimation } from './animation'
import { isDev } from '../utils/dev'

export class TargetAutomationDialog {
  #dialog: MdDialog | null = null
  #automation: TargetAutomation
  #appList: AppList
  #snackbar: Snackbar
  #lastState: TargetAutomationState | null = null

  constructor(automation: TargetAutomation, appList: AppList, snackbar: Snackbar) {
    this.#automation = automation
    this.#appList = appList
    this.#snackbar = snackbar
  }

  getElement(): DocumentFragment {
    const template = document.createElement('template')
    template.innerHTML = /* html */ `
      <md-dialog id="target-automation-dialog">
        <div slot="headline">默认模式与自动添加</div>
        <div slot="content" class="target-automation-content">
          <p class="target-automation-status" id="target-automation-status">正在读取配置…</p>
          <label class="switch-item outlined">
            <span>自动补齐全部已安装应用</span>
            <md-switch id="target-auto-add" icons></md-switch>
          </label>
          <p class="target-automation-note">包含系统应用。每 60 秒同步一次，新加入应用使用下面的默认模式；已有应用的手动模式会保留。</p>
          <div class="target-default-modes">
            <strong>新加入应用的默认模式</strong>
            <label><md-radio name="target-default-mode" value="generate"></md-radio><span>生成证书链（!）</span></label>
            <label><md-radio name="target-default-mode" value="auto"></md-radio><span>自动选择</span></label>
            <label><md-radio name="target-default-mode" value="hack"></md-radio><span>修改叶证书（?）</span></label>
          </div>
          <md-outlined-button id="target-apply-generate">全部应用统一为生成模式（!）</md-outlined-button>
          <p class="target-automation-note">上面的批量操作会更新所有已安装应用及已有目标的模式，并保留操作前列表。</p>
          <md-outlined-button id="target-restore">关闭自动添加并恢复启用前列表</md-outlined-button>
        </div>
        <div slot="actions">
          <md-outlined-button id="target-automation-close">关闭</md-outlined-button>
          <md-filled-button id="target-automation-save">保存默认设置</md-filled-button>
        </div>
      </md-dialog>`
    const fragment = template.content
    this.#dialog = fragment.querySelector<MdDialog>('#target-automation-dialog')!
    const dialog = this.#dialog
    dialog.querySelector('#target-automation-close')!.addEventListener('click', () => dialog.close())
    dialog.querySelector('#target-automation-save')!.addEventListener('click', () => void this.#save())
    dialog.querySelector('#target-apply-generate')!.addEventListener('click', () => void this.#applyGenerate())
    dialog.querySelector('#target-restore')!.addEventListener('click', () => void this.#restore())
    return fragment
  }

  initAnimation(): void { if (this.#dialog) applyDialogAnimation(this.#dialog) }

  async show(): Promise<void> {
    try {
      this.#render(await this.#automation.run('status'))
      this.#dialog?.show()
    } catch (error) { this.#snackbar.show(String(error), false) }
  }

  #mode(): TargetMode {
    return Array.from(this.#dialog?.querySelectorAll<MdRadio>('md-radio') || [])
      .find(r => r.checked)?.value as TargetMode || 'generate'
  }

  #auto(): boolean { return this.#dialog!.querySelector<MdSwitch>('#target-auto-add')!.selected }

  #render(state: TargetAutomationState): void {
    if (!this.#dialog) return
    if (isDev()) state.target_count = this.#appList.getTargetCount()
    this.#lastState = state
    this.#dialog.querySelector<MdSwitch>('#target-auto-add')!.selected = state.auto_add
    this.#dialog.querySelectorAll<MdRadio>('md-radio').forEach(r => r.checked = r.value === state.mode)
    this.#dialog.querySelector<HTMLElement>('#target-automation-status')!.textContent = state.supported
      ? `当前目标 ${state.target_count} 个 · ${state.backup ? '启用前列表已备份' : '首次同步时自动备份'}${state.last_sync ? ` · 最近同步：${state.last_sync}` : ''}`
      : '此功能适用于 Tricky Store OSS 的目标列表配置。'
    this.#dialog.querySelector<MdOutlinedButton>('#target-restore')!.disabled = !state.backup
    this.#appList.defaultMode = state.mode
  }

  async #perform(operation: () => Promise<TargetAutomationState>, message: string): Promise<void> {
    const buttons = Array.from(this.#dialog!.querySelectorAll<MdFilledButton | MdOutlinedButton>('md-filled-button, md-outlined-button'))
    buttons.forEach(b => b.disabled = true)
    try {
      const state = await operation()
      if (!isDev()) await this.#appList.refresh()
      this.#appList.syncSystemAppsWithConfig()
      await this.#appList.refresh(false)
      this.#render(state)
      this.#snackbar.show(message)
    } catch (error) { this.#snackbar.show(String(error), false) }
    finally {
      buttons.forEach(b => b.disabled = false)
      this.#dialog!.querySelector<MdOutlinedButton>('#target-restore')!.disabled = !this.#lastState?.backup
    }
  }

  async #save(): Promise<void> {
    const mode = this.#mode()
    await this.#perform(() => this.#automation.run('configure', mode, this.#auto()), '默认模式与自动添加设置已保存')
  }

  async #applyGenerate(): Promise<void> {
    await this.#perform(async () => {
      await this.#automation.run('configure', 'generate', this.#auto())
      const state = await this.#automation.run('apply', 'generate')
      if (isDev()) this.#appList.setAllInstalledMode('generate')
      return state
    }, '全部目标已设为生成模式（!）')
  }

  async #restore(): Promise<void> {
    await this.#perform(async () => {
      const state = await this.#automation.run('restore')
      if (isDev()) await this.#appList.refresh()
      return state
    }, '自动添加已关闭，启用前列表已恢复')
  }
}
