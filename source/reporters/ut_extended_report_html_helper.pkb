create or replace package body ut_extended_report_html_helper is
  /*
  utPLSQL - Version 3
  Copyright 2016 - 2017 utPLSQL Project
  
  Licensed under the Apache License, Version 2.0 (the "License"):
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at
  
      http://www.apache.org/licenses/LICENSE-2.0
  
  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
  */

  function get_details_file_content(a_object_id varchar2, a_unit ut_object_name, a_unit_coverage ut_coverage.t_unit_coverage)
    return clob is
    l_source_code   ut_varchar2_list;
    l_result        clob;

    function build_details_file_content(a_object_id varchar2, a_object_full_name varchar2, a_source_code ut_varchar2_list, a_coverage_unit ut_coverage.t_unit_coverage)
      return clob is
      l_file_part     varchar2(32767);
      l_result        clob;
      l_coverage_pct  number(5, 2);
      l_coverage_block_pct  number(5, 2);
      l_hits varchar2(30);
    begin
      dbms_lob.createtemporary(l_result, true);

     l_coverage_pct := ut_coverage_report_html_helper.coverage_pct(a_coverage_unit.covered_lines, a_coverage_unit.uncovered_lines);

     l_file_part := '<div class="source_table" id="' || a_object_id || '"><div class="header"> <h3>' ||
                     dbms_xmlgen.convert(a_object_full_name) || '</h3>' || '<h4><span class="' ||
                     ut_coverage_report_html_helper.coverage_css_class(l_coverage_pct) || '">' || l_coverage_pct || ' %</span> lines covered</h4>' ||
                     '<div> <b>' ||(a_coverage_unit.covered_lines + a_coverage_unit.uncovered_lines)
                        || '</b> relevant lines. ' || '<span class="green"><b>' || a_coverage_unit.covered_lines ||
                     '</b> lines covered</span> '|| 
                      '(including <span class="yellow"><b>' || a_coverage_unit.partcovered_lines ||
                      '</b> lines partially covered</span> '
                     || ') and <span class="red"><b>' || a_coverage_unit.uncovered_lines ||
                     '</b> lines missed</span>'||'</div></div><pre><ol>';
      ut_utils.append_to_clob(l_result, l_file_part);
    
      for line_no in 1 .. a_source_code.count loop
        if not a_coverage_unit.lines.exists(line_no) then
          l_file_part := '
            <li class="' || ut_coverage_report_html_helper.line_status(null) || '" data-hits="" data-linenumber="' || line_no || '">
            <code class="sql">' || (dbms_xmlgen.convert(a_source_code(line_no))) ||
                         '</code></li>';
        else
           l_hits := to_char(a_coverage_unit.lines(line_no).executions);
                         
          l_file_part := '
            <li class="' || ut_coverage_report_html_helper.line_status(a_coverage_unit.lines(line_no)) || '" data-hits="' ||
                         dbms_xmlgen.convert(l_hits)|| '" data-linenumber="' || (line_no) || '">';
          if a_coverage_unit.lines(line_no).executions > 0 then
            
            l_file_part := l_file_part || '
              <span class="hits">' || dbms_xmlgen.convert(l_hits) ||
                           '</span>';
          end if;
          l_file_part := l_file_part || '
              <code class="sql">' || (dbms_xmlgen.convert(a_source_code(line_no))) ||
                         '</code></li>';
        end if;
        ut_utils.append_to_clob(l_result, l_file_part);
      end loop;
    
      l_file_part := '</ol></pre></div>';
      ut_utils.append_to_clob(l_result, l_file_part);
      return l_result;
    end;
  begin
    l_source_code := ut_coverage_helper.get_tmp_table_object_lines(a_unit.owner, a_unit.name);
    dbms_lob.createtemporary(l_result, true);
    l_result := build_details_file_content(a_object_id
                                          ,a_unit.identity
                                          ,l_source_code
                                          ,a_unit_coverage
                                          );
    return l_result;
  end;

  function file_list(a_title varchar2, a_coverage ut_coverage.t_coverage) return clob is
    l_file_part     varchar2(32767);
    l_title         varchar2(100) := 'All files';
    l_coverage_pct  number(5, 2);
    l_coverage_block_pct  number(5, 2);
    l_result        clob;
    l_id            varchar2(50) := ut_coverage_report_html_helper.object_id(a_title);
    l_unit_coverage ut_coverage.t_unit_coverage;
    l_unit          ut_coverage.t_object_name;
  begin
    l_coverage_pct := ut_coverage_report_html_helper.coverage_pct(a_coverage.covered_lines, a_coverage.uncovered_lines);

    dbms_lob.createtemporary(l_result, true);

    l_file_part := '<div class="file_list_container" id="' || l_id || '">' || '<h2><span class="group_name">' || l_title ||
                   '</span>' || ' (<span class="covered_percent"><span class="' || ut_coverage_report_html_helper.coverage_css_class(l_coverage_pct) || '">' ||
                   l_coverage_pct || '%</span></span>' || ' lines covered'||
                   ' at <span class="covered_strength">' ||
                   '<span class="' ||ut_coverage_report_html_helper.line_hits_css_class(ut_coverage_report_html_helper.executions_per_line(a_coverage.executions
                                                             ,a_coverage.uncovered_lines + a_coverage.covered_lines)) || '">' ||
                      ut_coverage_report_html_helper.executions_per_line(a_coverage.executions, a_coverage.uncovered_lines + a_coverage.covered_lines)
                     || '</span></span> hits/line)</h2>' || '<a name="' || l_id || '"></a>' || '<div><b>' ||
                      a_coverage.objects.count || '</b> files in total. </div><div>' || '<b>' || 
                      (a_coverage.uncovered_lines + a_coverage.covered_lines)
                   || '</b> relevant lines. ' || '<span class="green"><b>' || a_coverage.covered_lines ||
                   '</b> lines covered</span>'||
                   ' (inlcluding <span class="yellow"><b>' || a_coverage.partcovered_lines ||
                   '</b> lines partially covered</span>' || ') and <span class="red"><b>' || a_coverage.uncovered_lines || '</b> lines missed.</span>'||
                   '<table class="file_list"><thead>' || '<tr>' ||
                   '<th>File</th><th>% covered</th><th>Lines</th><th>Relevant Lines</th><th>Lines covered</th><th>Lines missed</th><th>'
                   ||'Avg. Hits / Line </th>' ||
                   '</tr></thead><tbody>';
    ut_utils.append_to_clob(l_result, l_file_part);
    l_unit := a_coverage.objects.first;
    loop
      exit when l_unit is null;
      l_unit_coverage := a_coverage.objects(l_unit);
      l_coverage_pct := ut_coverage_report_html_helper.coverage_pct(l_unit_coverage.covered_lines, l_unit_coverage.uncovered_lines);

     l_file_part := chr(10) || '<tr>' || '<td class="strong">' || ut_coverage_report_html_helper.link_to_source_file(dbms_xmlgen.convert(l_unit)) ||
                     '</td>' || '<td class="' || ut_coverage_report_html_helper.coverage_css_class(l_coverage_pct) || ' strong">' || l_coverage_pct ||
                     ' %</td>' || '<td>' || l_unit_coverage.total_lines || '</td>' || '<td>' || 
                       (l_unit_coverage.covered_lines + l_unit_coverage.uncovered_lines) || '</td>' || '<td>' ||
                       l_unit_coverage.covered_lines || '</td><td>' || l_unit_coverage.uncovered_lines || '</td>' || 
                       '<td>' || to_char(ut_coverage_report_html_helper.executions_per_line(l_unit_coverage.executions
                                        ,l_unit_coverage.uncovered_lines + l_unit_coverage.covered_lines))
                       || '</td></tr>';
      ut_utils.append_to_clob(l_result, l_file_part);
      l_unit := a_coverage.objects.next(l_unit);
    end loop;
    l_file_part := '</tbody></table></div>';
    ut_utils.append_to_clob(l_result, l_file_part);
    return l_result;
  end;

  /*
  * public definitions
  */
  function get_index(a_coverage_data ut_coverage.t_coverage, a_assets_path varchar2, a_project_name varchar2 := null, a_command_line varchar2 := null)
    return clob is
  
    l_file_part     varchar2(32767);
    l_result        clob;
    l_title         varchar2(250);
    l_coverage_pct  number(5, 2);
    l_time_str      varchar2(50);
    l_using         varchar2(1000);
    l_unit          ut_coverage.t_full_name;
  begin
      l_coverage_pct := ut_coverage_report_html_helper.coverage_pct(a_coverage_data.covered_lines, a_coverage_data.uncovered_lines);

    l_time_str := ut_utils.to_string(sysdate);
    l_using := case
                 when a_command_line is not null then
                  '<br/>using ' || dbms_xmlgen.convert(a_command_line)
               end;
    dbms_lob.createtemporary(l_result, true);
  
    l_title := case
                 when a_project_name is null then
                  'Code coverage'
                 else
                  dbms_xmlgen.convert(a_project_name) || ' code coverage'
               end;
    --TODO - build main file containing total run data and per schema data
    l_file_part := '<!DOCTYPE html><html xmlns=''http://www.w3.org/1999/xhtml''><head>' || '<title>' || l_title ||
                   '</title>' || '<meta http-equiv="content-type" content="text/html; charset=utf-8" />' ||
                   '<script src=''' || a_assets_path || 'application.js'' type=''text/javascript''></script>' ||
                   '<link href=''' || a_assets_path ||
                   'application.css'' media=''screen, projection, print'' rel=''stylesheet'' type=''text/css''>' ||
                   '<link rel="shortcut icon" type="image/png" href="' || a_assets_path || 'favicon_' ||
                   ut_coverage_report_html_helper.coverage_css_class(l_coverage_pct) || '.png" />' || '<link rel="icon" type="image/png" href="' ||
                   a_assets_path || 'favicon_' || ut_coverage_report_html_helper.coverage_css_class(l_coverage_pct) || '.png" />' || '</head>' ||
                   '<body><div id="loading"><img src="' || a_assets_path || 'loading.gif" alt="loading"/></div>' ||
                   '<div id="wrapper" style="display:none;">' ||
                   '<div class="timestamp">Generated <abbr class="timeago" title="' || l_time_str || '">' || l_time_str ||
                   '</abbr></div>' || '<ul class="group_tabs"></ul>' || '<div id="content">';
    ut_utils.append_to_clob(l_result, l_file_part);
  
    dbms_lob.append(l_result, file_list('All files', a_coverage_data));
  
    l_file_part := chr(10) || '</div><div id="footer">' ||
                   'Generated by <a href="http://github.com/utPLSQL/utPLSQL">utPLSQL ' || ut_utils.gc_version ||
                   '</a><br/>' ||
                   'Based on <a href="http://github.com/colszowka/simplecov-html">simplecov-html</a> v0.10.0 ' ||
                   l_using || '' || '</div><div class="source_files">';
    ut_utils.append_to_clob(l_result, l_file_part);
  
    l_unit := a_coverage_data.objects.first;
    loop
      exit when l_unit is null;
      dbms_lob.append(l_result
                     ,get_details_file_content(ut_coverage_report_html_helper.object_id(l_unit)
                                              ,ut_object_name(a_coverage_data.objects(l_unit).owner
                                                             ,a_coverage_data.objects(l_unit).name)
                                              ,a_coverage_data.objects(l_unit)
                                              ));
      l_unit := a_coverage_data.objects.next(l_unit);
    end loop;
  
    l_file_part := '</div></div></body></html>';
  
    ut_utils.append_to_clob(l_result, l_file_part);
    return l_result;
  end;

end;
/
