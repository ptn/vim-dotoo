if exists('g:autoloaded_dotoo_parser_logbook')
  finish
endif
let g:autoloaded_dotoo_parser_logbook = 1

let s:syntax = dotoo#parser#lexer#syntax()
let s:logbook_methods = {}
function! s:logbook_methods.serialize() dict
  if empty(self.logs) | return [] | endif
  let logs = []
  call add(logs, ':LOGBOOK:')
  for log in self.logs
    if log.type == s:syntax.logbook_clock.type
      let log_string = 'CLOCK: [' . log['start'].to_string(g:dotoo#time#datetime_format) . ']'
      if has_key(log, 'end')
        let diff_time = log['end'].diff_time(log['start']).to_string(g:dotoo#time#time_format)
        let log_string .= '--[' . log['end'].to_string(g:dotoo#time#datetime_format) . ']'
        let log_string .= ' => ' . diff_time
      endif
      call add(logs, log_string)
    elseif log.type == s:syntax.logbook_state_change.type
      call add(logs, '- State ' .
            \ '"'.log['to'].'"' .
            \ ' from ' .
            \ '"'.log['from'].'"' .
            \ ' [' . log['time'].to_string(g:dotoo#time#datetime_format) . ']')
    endif
  endfor
  call add(logs, ':END:')
  return logs
endfunction

function! s:logbook_methods.log(log) dict
  call insert(self.logs, a:log)
endfunction

function! s:logbook_methods.start_clock() dict
  let log = {'type': s:syntax.logbook_clock.type}
  let log['start'] = dotoo#time#new()
  call self.log(log)
endfunction

function! s:logbook_methods.stop_clock() dict
  let log = get(self.logs, 0) " get latest log
  if !empty(log) && !has_key(log, 'end') " not already stopped
    let log['end'] = dotoo#time#new()
  endif
endfunction

function! s:logbook_methods.clocking_summary() dict
  let log = self.logs[0]
  if !has_key(log, 'end')
    return log['start'].diff_time(dotoo#time#new()).to_string(g:dotoo#time#time_format)
  endif
endfunction

function! s:logbook_methods.summary(time, span) dict
  if a:span ==# 'day'
    let logs = map(self.logs, 'v:val.eq_date(a:time)')
  endif
  let summary = 0
  for log in logs
    let summary += log['end'].diff_time(log['start'])
  endfor
  return sumary
endfunction

function! dotoo#parser#logbook#new(...)
  let tokens = a:0 ? a:1 : []
  let logbook = {'logs': []}
  while len(tokens)
    let token = remove(tokens, 0)
    let log = {'type': token.type}
    if token.type == s:syntax.logbook.type
      continue " Skip the :LOGBOOK: token
    elseif token.type == s:syntax.logbook_clock.type
      let log.start = dotoo#time#new(token.content[0])
      if get(token.content, 2)
        let log.end = dotoo#time#new(token.content[2])
      endif
    elseif token.type == s:syntax.logbook_state_change.type
      let log.to = token.content[0]
      let log.from = token.content[1]
      let log.time = dotoo#time#new(token.content[2])
    elseif token.type == s:syntax.drawer_end.type
      break " Skip & end
    endif
    call add(logbook.logs, log)
  endwhile
  call extend(logbook, s:logbook_methods)
  return logbook
endfunction
