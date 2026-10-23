package edu.bingol.backend.menu.dto;

import edu.bingol.backend.menu.MenuDay;
import java.util.List;

/** Bir gunun menusu. date ISO (yyyy-MM-dd). */
public record MenuResponse(String date, List<String> items) {

    public static MenuResponse of(MenuDay d) {
        return new MenuResponse(d.getMenuDate().toString(), List.of(d.getItems().split("\n")));
    }
}
