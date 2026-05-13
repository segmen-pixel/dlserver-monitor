HISTORY_LEN = 60   # 60 samples × 3s = 3 minutes

# Persistent history across re-renders (per-widget namespace)
window.dlhist_dlserver ||= {}

metrics = [
  {key: 'gpu0_temp',  label: 'Temp', max: 100,   unit: ' °C', color: '#88ff88', fmt: 'int'}
  {key: 'gpu0_fan',   label: 'Fan',  max: 100,   unit: '%',   color: '#50c8ff', fmt: 'int'}
  {key: 'gpu0_util',  label: 'Util', max: 100,   unit: '%',   color: '#7896ff', fmt: 'int'}
  {key: 'gpu0_mem',   label: 'VRAM', max: 32768, unit: ' MiB', color: '#c878dc', fmt: 'int'}
  {key: 'gpu0_power', label: 'Pwr',  max: 600,   unit: ' W',  color: '#ffb450', fmt: 'flt'}
  {key: 'gpu1_temp',  label: 'Temp', max: 100,   unit: ' °C', color: '#88ff88', fmt: 'int'}
  {key: 'gpu1_fan',   label: 'Fan',  max: 100,   unit: '%',   color: '#50c8ff', fmt: 'int'}
  {key: 'gpu1_util',  label: 'Util', max: 100,   unit: '%',   color: '#7896ff', fmt: 'int'}
  {key: 'gpu1_mem',   label: 'VRAM', max: 24576, unit: ' MiB', color: '#c878dc', fmt: 'int'}
  {key: 'gpu1_power', label: 'Pwr',  max: 350,   unit: ' W',  color: '#ffb450', fmt: 'flt'}
  {key: 'cpu_pkg',    label: 'Pkg',  max: 100,   unit: ' °C', color: '#ff8c50', fmt: 'int'}
  {key: 'cpu_max',    label: 'Max',  max: 100,   unit: ' °C', color: '#ff8c50', fmt: 'int'}
]

rowHtml = (m) ->
  """
    <div class="row">
      <div class="label">#{m.label}</div>
      <div class="bar"><div class="fill" id="bar1-#{m.key}" style="background: #{m.color}"></div></div>
      <svg class="spark" id="spark1-#{m.key}" viewBox="0 0 240 16" preserveAspectRatio="none">
        <polyline fill="none" stroke="#{m.color}" stroke-width="1.4" />
      </svg>
      <div class="value" id="val1-#{m.key}">--</div>
    </div>
  """

groupHtml = (prefix) ->
  (rowHtml(m) for m in metrics when m.key.startsWith(prefix)).join('')

command: "/usr/bin/ssh -i $HOME/.ssh/id_ed25519 -o BatchMode=yes -o ConnectTimeout=5 dl-server powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/yuki/bin/trainer-stats.ps1 2>&1"

refreshFrequency: 3000

style: """
  top 0
  left 0
  width 540px
  background rgba(16, 16, 21, 0.88)
  border-radius 8px
  padding 14px 18px
  font-family -apple-system, "Segoe UI", sans-serif
  color #fff
  box-shadow 0 8px 32px rgba(0, 0, 0, 0.4)

  h1
    margin 0
    font-size 14px
    font-weight 600
    color #ffb450
    letter-spacing 0.5px

  .sub
    font-size 9px
    color #b4b4c8
    margin-bottom 10px

  .header
    margin-top 10px
    margin-bottom 4px
    font-size 11px
    font-weight 600
    color #78dcff
    letter-spacing 0.3px

    &.cpu
      color #ffb450

  .row
    display grid
    grid-template-columns 46px 90px 1fr 84px
    align-items center
    column-gap 10px
    height 20px

  .label
    font-size 10px
    color #b4b4c8

  .bar
    height 8px
    background rgba(40, 40, 50, 0.85)
    border-radius 2px
    overflow hidden

    .fill
      height 100%
      width 0%
      transition width 0.4s ease-out

  .spark
    height 18px
    width 100%
    background rgba(30, 30, 38, 0.7)
    border-radius 2px

  .value
    font-family Menlo, Consolas, monospace
    font-size 10px
    text-align right
    color #fff

  .footer
    margin-top 10px
    font-size 8px
    color #8c8ca0
    letter-spacing 0.2px

  .err
    color #ff6464
    font-size 10px
    padding 8px
    word-break break-all

    &.ssh
      color #ffb450
    &.ps
      color #ff6464
    &.parse
      color #ffe450
    &.empty
      color #b478ff
    &.ok
      color #64c878
      font-size 8px
      padding 2px 8px 0 8px
"""

render: -> """
  <h1>DL-SERVER</h1>
  <div class="sub">trainer @ 100.113.135.38 (Windows)</div>

  <div class="header">GPU 0  RTX 5090</div>
  #{groupHtml('gpu0')}

  <div class="header">GPU 1  RTX 3090</div>
  #{groupHtml('gpu1')}

  <div class="header cpu">CPU  i9-13900KF  (ACPI)</div>
  #{groupHtml('cpu')}

  <div class="footer">SSH every 3s · history 3 min · bar=current  line=trend</div>
  <div class="err" id="errmsg1" style="display:none"></div>
"""

update: (output, domEl) ->
  window.dlmon ?= {}
  state = window.dlmon.dlserver ?= {errCount: 0, lastOk: 0, notified: false}

  errEl = domEl.querySelector("#errmsg1")
  out = (output ? '').toString().trim()
  ts = new Date().toLocaleTimeString('ja-JP', {hour12: false})
  now = Date.now()

  # error classification
  errKind = null
  errMsg = null
  if not out
    errKind = 'empty'
    errMsg = "no output (ssh dead / fetch timeout)"
  else if /Permission denied|Could not resolve|Connection refused|Operation timed out|Connection closed|kex_exchange|Host key|ssh:/i.test(out)
    errKind = 'ssh'
    errMsg = out.slice(0, 180)
  else if /At line:|CategoryInfo|FullyQualifiedErrorId|System\.Management\.Automation|cannot find|is not recognized as/i.test(out)
    errKind = 'ps'
    errMsg = out.slice(0, 180)
  else
    fields = out.split(',')
    if fields.length < 12
      errKind = 'parse'
      errMsg = "got #{fields.length} fields (expected 12): #{out.slice(0, 120)}"

  if errKind
    state.errCount++
    suffix = ""
    if state.lastOk
      ago = Math.floor((now - state.lastOk) / 1000)
      suffix = if ago < 60 then " | last ok #{ago}s ago" else " | last ok #{Math.floor(ago/60)}m ago"
    errEl.style.display = 'block'
    errEl.className = "err #{errKind}"
    errEl.textContent = "[#{errKind}] #{ts} (×#{state.errCount}) #{errMsg}#{suffix}"

    # 5回連続失敗で macOS 通知（復帰までは1度のみ）
    if state.errCount >= 5 and not state.notified
      state.notified = true
      try
        msg = "[#{errKind}] " + errMsg.slice(0, 80).replace(/['"\\]/g, '')
        require('child_process').exec(
          "osascript -e 'display notification \"#{msg}\" with title \"DL-SERVER widget down\"'"
        )
      catch e
        console.error("notify failed: #{e}")
    return

  # success
  state.errCount = 0
  state.lastOk = now
  state.notified = false

  errEl.style.display = 'block'
  errEl.className = "err ok"
  errEl.textContent = "ok @ #{ts}"
  fields = out.split(',')

  values = {}
  for m, i in metrics
    v = parseFloat(fields[i])
    values[m.key] = if isFinite(v) then v else null  # NaN防御

  for m in metrics
    try
      val = values[m.key]
      valEl = domEl.querySelector("#val1-#{m.key}")
      bar = domEl.querySelector("#bar1-#{m.key}")

      if val is null
        if valEl
          valEl.textContent = "--"
          valEl.style.color = '#888'
        continue

      # 範囲外検知 (max+50% 超 / 負値)
      isOutlier = val < 0 or val > m.max * 1.5
      pct = Math.min(100, Math.max(0, (val / m.max) * 100))

      if bar
        bar.style.width = "#{pct}%"
        bar.style.background = if isOutlier then '#ff64ff' else m.color

      if valEl
        txt = if m.fmt == 'flt' and val % 1 != 0
          "#{val.toFixed(1)}#{m.unit}"
        else
          "#{Math.round(val)}#{m.unit}"
        valEl.textContent = txt
        valEl.style.color = if isOutlier then '#ff64ff' else '#fff'

      window.dlhist_dlserver[m.key] ||= []
      h = window.dlhist_dlserver[m.key]
      h.push(pct)
      h.shift() while h.length > HISTORY_LEN

      spark = domEl.querySelector("#spark1-#{m.key}")
      if spark and h.length > 1
        poly = spark.querySelector('polyline')
        step = 240 / Math.max(HISTORY_LEN - 1, 1)
        offset = Math.max(0, HISTORY_LEN - h.length) * step
        pts = (h.map (v, i) -> "#{(offset + i * step).toFixed(1)},#{(15 - (v / 100) * 14).toFixed(1)}").join(' ')
        poly.setAttribute('points', pts)
    catch e
      console.error("metric #{m.key}: #{e.message}")
